//
//  ViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/17/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import UIKit
import Alamofire

class InitializationViewController: UIViewController {

    var flag = true
    override func viewDidAppear(_ animated: Bool) {
        guard self.flag else { return }
        self.flag = false

        if Settings.shared.isAuthenticated() {
            self.authAndProceed()
        } else {
            self.performSegue(withIdentifier: "toWebAuth", sender: nil)
        }
    }
    
    @IBAction func unwindFromWebAuth(_ segue: UIStoryboardSegue) {
        self.dismiss(animated: false, completion: {
            self.authAndProceed()
        })
    }

    func authAndProceed() {
        if self.apiInit() {
            Settings.shared.set(value: true, for: .isAuthenticated)
            self.performSegue(withIdentifier: "proceed", sender: nil)
            self.flag = true
        } else {
            self.performSegue(withIdentifier: "toWebAuth", sender: nil)
        }
    }

    func apiInit() -> Bool {
        do {
            try SteamPollManager.shared.initialize()
            SteamPollManager.shared.isRunning = true
            SteamPollManager.shared.start()

            return true
        } catch SteamApi.RequestError.AuthFailed {

        } catch let e {
            let alert = UIAlertController(title: "Error:", message: String(describing: e), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Quit", style: .destructive, handler: { _ in exit(0) }))
            self.present(alert, animated: true, completion: nil)
        }

        return false
    }
}

class WebAuthenticationViewController: UIViewController, UIWebViewDelegate {
    @IBOutlet weak var webView: UIWebView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    let url = URL(string: "https://steamcommunity.com/chat")!

    override func viewDidAppear(_ animated: Bool) {
        self.webView.loadRequest(URLRequest(url: self.url))
    }

    func webViewDidStartLoad(_ webView: UIWebView) {
        self.activityIndicator.startAnimating()
    }

    func webViewDidFinishLoad(_ webView: UIWebView) {
        self.activityIndicator.stopAnimating()

        if webView.request?.url == self.url {
            self.performSegue(withIdentifier: "unwindFromAuth", sender: nil)
        }
    }
}

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self

        let navigationController = self.viewControllers.first as! UINavigationController
        navigationController.isNavigationBarHidden = true
        navigationController.interactivePopGestureRecognizer?.delegate = nil
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
        self.dismiss(animated: true, completion: nil)
    }

    static let showMasterViewSelector = #selector(showMasterViewAction(_:))
    @IBAction func showMasterViewAction(_ sender: AnyObject) {
    }
}

