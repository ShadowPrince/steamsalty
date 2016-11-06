//
//  ViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/17/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import UIKit
import Alamofire

class WebAuthenticationViewController: UIViewController, UISplitViewControllerDelegate {
    let queue = OperationQueue()

    @IBOutlet weak var webView: UIWebView!

    override func viewDidAppear(_ animated: Bool) {
        if UserDefaults.standard.bool(forKey: "wasAuthenticated") {
            self.authCompletedAction(self)
        } else {
            self.loadWebAuth()
        }
    }

    @IBAction func authCompletedAction(_ sender: AnyObject) {
        let alert = UIAlertController(title: "Loading...", message: "...", preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)

        self.queue.addOperation {
            let result = self.apiInit()
            OperationQueue.main.addOperation {
                if result {
                    UserDefaults.standard.set(true, forKey: "wasAuthenticated")
                    self.performSegue(withIdentifier: "proceedSegue", sender: nil)
                } else {
                    self.loadWebAuth()
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    func loadWebAuth() {
        self.webView.loadRequest(URLRequest(url: URL(string: "http://steamcommunity.com/chat")!))
    }

    func apiInit() -> Bool {
        do {
            try SteamPollManager.shared.initialize()
            SteamPollManager.shared.start()
            return true
        } catch SteamApi.RequestError.AuthFailed {
            let alert = UIAlertController(title: "Error:", message: "Authentication failed", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { _ in alert.dismiss(animated: true, completion: nil) }))
            self.present(alert, animated: true, completion: nil)
            return false
        } catch let e {
            let alert = UIAlertController(title: "Error:", message: String(describing: e), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Quit", style: .destructive, handler: { _ in exit(0) }))
            self.present(alert, animated: true, completion: nil)
            return false
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
}

