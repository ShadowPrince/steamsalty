//
//  ViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/17/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import UIKit
import Alamofire

class WebAuthenticationViewController: UIViewController, UIWebViewDelegate {
    @IBOutlet weak var webView: UIWebView!

    let url = URL(string: "https://steamcommunity.com/chat")!

    override func viewDidAppear(_ animated: Bool) {
        self.loadWebAuth()
    }

    func webViewDidFinishLoad(_ webView: UIWebView) {
        if webView.request?.url == self.url {
            if self.apiInit() {
                self.performSegue(withIdentifier: "proceedSegue", sender: nil)
            } else {
                self.loadWebAuth()
            }
        }

        print(webView.request?.url)
    }

    func loadWebAuth() {
        self.webView.loadRequest(URLRequest(url: self.url))
    }

    func apiInit() -> Bool {
        do {
            try SteamPollManager.shared.initialize()
            SteamPollManager.shared.start()

            return true
        } catch SteamApi.RequestError.AuthFailed {
            self.presentError("Authentication failed")
        } catch let e {
            let alert = UIAlertController(title: "Error:", message: String(describing: e), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Quit", style: .destructive, handler: { _ in exit(0) }))
            self.present(alert, animated: true, completion: nil)
        }

        return false
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

