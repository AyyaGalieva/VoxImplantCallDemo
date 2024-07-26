//
//  CallAssembly.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

import UIKit

protocol CallAssemblyProtocol {
    func module() -> UIViewController
}

final class CallAssembly: Assembly, CallAssemblyProtocol {

    func module() -> UIViewController {
        let viewController = CallViewController()
        let voipCallService = VoipCallService()
        let presenter = CallPresenter(
            viewController: viewController,
            voipCallService: voipCallService
        )
        viewController.presenter = presenter

        return viewController
    }
}
