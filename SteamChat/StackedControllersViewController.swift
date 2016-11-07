//
//  StackedControllersViewController.swift
//  SteamChat
//
//  Created by shdwprince on 10/30/16.
//  Copyright © 2016 shdwprince. All rights reserved.
//

import Foundation
import UIKit

private enum DragDirection {
    case vertical
    case left
    case right
}

protocol StackedContainersViewControllerDataSource {
    var stackCount: Int { get }
    var stackIndex: Int { get }
    var stackNextIndex: Int { get }

    func stackDrop()
    func stackPush()
}

class StackedContainerViewController: UIViewController {
    func becomeForeground() {}
    func becomeBackground() {}
    func setIndex(_ index: Int) {}
}

class StackedContainersViewController: UIViewController {
    @IBOutlet weak var foregroundView: UIView!
    @IBOutlet weak var backgroundView: UIView!
    var foregroundController, backgroundController: StackedContainerViewController!

    var dataSource: StackedContainersViewControllerDataSource!

    private var topOffset: CGFloat = 0.0
    private let headerHeight: CGFloat = 30.0

    private var dragLocation: CGPoint?
    private var dragDirection: DragDirection?

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidLoad()
        self.viewDidLayoutSubviews()
        self.foregroundViewToDefaultPosition()
        self.backgroundViewToDefaultPosition()
        
        if self.dataSource.stackCount > 0 {
            self.foregroundController.setIndex(self.dataSource.stackIndex)
            self.foregroundController.becomeForeground()
        }

        if self.dataSource.stackCount > 1 {
            self.backgroundController.setIndex(self.dataSource.stackNextIndex)
            self.backgroundController.becomeBackground()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.topOffset = self.prefersStatusBarHidden ? 0.0 : 20.0
        self.topOffset += self.navigationController?.isNavigationBarHidden ?? false == false ? 48.0 : 0.0
        self.foregroundViewToDefaultPosition()
        self.backgroundViewToDefaultPosition()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "foregroundSegue"?:
            self.foregroundController = segue.destination as! StackedContainerViewController
        case "backgroundSegue"?:
            self.backgroundController = segue.destination as! StackedContainerViewController
        default:
            break
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1, let touch = touches.first else { return }
        guard touch.location(in: self.view).y <= self.headerHeight * 2 + self.topOffset else { return }
        guard self.isStackSupportPushing() else { return }
        
        let location = touch.location(in: self.view)
        self.dragLocation = CGPoint(x: location.x - self.foregroundView.frame.origin.x,
                                    y: location.y - self.foregroundView.frame.origin.y)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let start = self.dragLocation, let end = touches.first?.location(in: self.view) {
            let dX = abs(end.x - start.x), dY = abs(end.y - start.y)
            if max(dX, dY) > 100.0 {
                self.dragDirection = dX > dY ? (end.x > start.x ? .right : .left) : .vertical
            }
            
            switch self.dragDirection {
            case .left?, .right?:
                self.foregroundView.frame.origin = CGPoint(x: end.x - start.x, y: self.foregroundView.frame.origin.y)
            case .vertical?:
                self.foregroundView.frame.origin = CGPoint(x: self.foregroundView.frame.origin.x, y: end.y - start.y)
            case nil:
                self.foregroundView.frame.origin = CGPoint(x: end.x - start.x, y: end.y - start.y)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        func embedOut(_ direction: DragDirection) {
            switch direction {
            case .vertical:
                self.foregroundView.frame.origin = CGPoint(x: self.foregroundView.frame.origin.x, y: self.view.frame.height)
            case .right:
                self.foregroundView.frame.origin = CGPoint(x: self.view.frame.width, y: self.foregroundView.frame.origin.y)
            case .left:
                self.foregroundView.frame.origin = CGPoint(x: -self.view.frame.width, y: self.foregroundView.frame.origin.y)
            }
        }
        
        func swapEmbeds() {
            let _frontEmbed = self.foregroundView
            self.foregroundView = self.backgroundView
            self.backgroundView = _frontEmbed
            
            self.foregroundView.removeFromSuperview()
            self.backgroundView.removeFromSuperview()
            
            self.view.addSubview(self.backgroundView)
            self.view.addSubview(self.foregroundView)

            let _frontController = self.foregroundController
            self.foregroundController = self.backgroundController
            self.backgroundController = _frontController

            self.pushStack()
        }

        let outDuration = 0.2, frontShiftDuration = 0.1, resetDuration = 0.2

        switch self.dragDirection {
        case let direction? where direction == .left || direction == .right || direction == .vertical:
            UIView.animate(
                withDuration: outDuration,
                animations: { embedOut(direction) },
                completion: { _ in
                    if direction != .vertical {
                        self.dropStack()
                    }

                    swapEmbeds()

                    if self.isStackSupportPushing() {
                        let backgroundOffset = self.headerHeight - self.topOffset
                        self.backgroundView.frame = CGRect(x: 0, y: -backgroundOffset, width: self.view.frame.width, height: self.view.frame.height - backgroundOffset)
                    }

                    UIView.animate(withDuration: frontShiftDuration, animations: { self.foregroundViewToDefaultPosition() } , completion: { _ in self.foregroundController.becomeForeground() })
                    UIView.animate(withDuration: frontShiftDuration, animations: { self.backgroundViewToDefaultPosition() } , completion: { _ in self.backgroundController.becomeBackground() })
            })
        default: UIView.animate(withDuration: resetDuration) {
            self.backgroundViewToDefaultPosition()
            self.foregroundViewToDefaultPosition()
            }
        }

        self.dragLocation = nil
        self.dragDirection = nil
    }

    private func isStackSupportPushing() -> Bool {
        return self.dataSource.stackCount > 1
    }

    private func dropStack() {
        self.dataSource.stackDrop()
    }
    
    private func pushStack() {

        guard self.dataSource.stackCount > 0 else {
            return
        }

        self.dataSource.stackPush()
        self.backgroundController.setIndex(self.dataSource.stackNextIndex)
    }
    
    private func foregroundViewToDefaultPosition() {
        let offset = self.isStackSupportPushing() ? self.headerHeight - 6 + self.topOffset : self.topOffset
        self.foregroundView.frame = CGRect(x: 0, y: offset, width: self.view.frame.width, height: self.view.frame.height - offset)
    }
    
    private func backgroundViewToDefaultPosition() {
        self.backgroundView.frame = CGRect(x: 0, y: 0 + self.topOffset, width: self.view.frame.width, height: self.view.frame.height - self.topOffset)
    }
}
