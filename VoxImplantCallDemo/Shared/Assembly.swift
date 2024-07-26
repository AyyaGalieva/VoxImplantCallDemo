//
//  Assembly.swift
//  VoxImplantDemo
//
//  Created by Ayya Galieva on 25.07.2024.
//

class Assembly {
    let assemblyFactory: AssemblyFactory

    init(assemblyFactory: AssemblyFactory) {
        self.assemblyFactory = assemblyFactory
    }
}

protocol AssemblyFactoryProtocol: AnyObject {

    var callAssembly: CallAssemblyProtocol { get }
}

final class AssemblyFactory: AssemblyFactoryProtocol {

    var callAssembly: CallAssemblyProtocol {
        CallAssembly(assemblyFactory: self)
    }
}

