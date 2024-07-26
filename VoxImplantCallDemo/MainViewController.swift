//
//  MainViewController.swift
//  VoxImplantCallDemo
//
//  Created by Ayya Galieva on 26.07.2024.
//

import UIKit

class MainViewController: UIViewController {

    private let assemblyFactory = AssemblyFactory()

    @IBOutlet private weak var startButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func startTapped(_ sender: Any) {
        let callModule = assemblyFactory.callAssembly.module()
        self.present(callModule, animated: true)
    }
}
