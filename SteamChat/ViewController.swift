//
//  ViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/17/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import UIKit
import Alamofire

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate, SteamPollManagerDelegate, UIPopoverPresentationControllerDelegate {
    private var authAttempt = false, authInProcess = false
    private var authIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self

        let navigationController = self.viewControllers.first as! UINavigationController
        navigationController.isNavigationBarHidden = true
        navigationController.interactivePopGestureRecognizer?.delegate = nil

        self.authIndicator.hidesWhenStopped = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !self.authAttempt {
            self.authAttempt = true
            self.authInProcess = true
            self.authIndicator.startAnimating()

            self.presentBlurredOverlay(titled: "Authenticating...", indicator: self.authIndicator)
            let toWebAuthClosure: (Error) -> Void = { _ in self.presentWebView() }

            if Settings.shared.isAuthenticated() {
                OperationQueue.background.addAsyncDoTry({ try SteamPollManager.shared.initialize() },
                                                        success: { self.authCompleted() },
                                                        exception: toWebAuthClosure )
            } else {
                toWebAuthClosure(SteamApi.RequestError.AuthFailed)
            }
        }
    }
    
    @IBAction func unwindFromWebAuth(_ segue: UIStoryboardSegue) {
        self.dismiss(animated: false, completion: {
            self.authIndicator.startAnimating()
            self.authCompleted()
        })
    }

    static let shouldStopAnimatingSelector = #selector(shouldStopAnimating(_:))
    @IBAction func shouldStopAnimating(_ sender: AnyObject?) {
        self.authIndicator.stopAnimating()
    }

    static let shouldStartAnimatingSelector = #selector(shouldStartAnimating(_:))
    @IBAction func shouldStartAnimating(_ sender: AnyObject?) {
        self.authIndicator.startAnimating()
    }

    func authCompleted() {
        SteamPollManager.shared.delegates.append(self)
        SteamPollManager.shared.isRunning = true
        SteamPollManager.shared.start()

        Settings.shared.set(value: true, for: .isAuthenticated)
    }

    func pollError(_ error: Error, manager: SteamPollManager) { }
    func pollReceived(events: [SteamEvent], manager: SteamPollManager) { }
    func pollStatus(_ user: SteamUser, contacts: [SteamUser], emotes: [SteamEmoteName]) {
        OperationQueue.main.addOperation {
            if self.authInProcess {
                self.authInProcess = false
                self.dismissBlurredOverlay()
            }
        }
    }

    func presentWebView() {
        let ctrl = self.storyboard!.instantiateViewController(withIdentifier: "webAuthController")
        ctrl.modalPresentationStyle = .popover
        ctrl.preferredContentSize = CGSize(width: self.view.frame.width - 16.0, height: self.view.frame.height / 2)
        
        if let popover = ctrl.popoverPresentationController {
            popover.delegate = self
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.frame.width / 2, y: self.view.frame.height / 2 - 10.0, width: 1, height: 1)
            popover.permittedArrowDirections = .down
        }
        
        self.present(ctrl, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        return false
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }

    static let hideSenderViewIfCollapsedSelector = #selector(hideSenderViewIfCollapsed(_:))
    @IBAction func hideSenderViewIfCollapsed(_ sender: AnyObject) {
        if let view = sender as? UIView {
            view.isHidden = !self.isCollapsed
        }
    }

    static let unwindToAuthActionSelector = #selector(unwindToAuthAction(_:))
    @IBAction func unwindToAuthAction(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
        self.authAttempt = false
        self.viewDidAppear(true)
    }

    static let showMasterViewSelector = #selector(showMasterViewAction(_:))
    @IBAction func showMasterViewAction(_ sender: AnyObject) {
    }
}

class WebAuthenticationViewController: UIViewController, UIWebViewDelegate {
    @IBOutlet weak var webView: UIWebView!

    var authTry = 0
    let url = URL(string: "https://steamcommunity.com/chat")!

    override func viewDidAppear(_ animated: Bool) {
        self.webView.loadRequest(URLRequest(url: self.url))
    }

    func webViewDidStartLoad(_ webView: UIWebView) {
        self.targetPerform(SplitViewController.shouldStartAnimatingSelector, sender: self)
    }

    func webViewDidFinishLoad(_ webView: UIWebView) {
        self.targetPerform(SplitViewController.shouldStopAnimatingSelector, sender: self)

        if webView.request?.url == self.url {
            do {
                try SteamPollManager.shared.initialize()
                self.performSegue(withIdentifier: "unwindFromAuth", sender: nil)
            } catch let e {
                self.presentError(e)
                self.authTry += 1
                
                if self.authTry < 3 {
                    self.webView.loadRequest(URLRequest(url: self.url))
                }
            }
        }
    }
}

