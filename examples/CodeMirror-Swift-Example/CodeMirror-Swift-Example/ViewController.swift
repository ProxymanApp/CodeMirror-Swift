//
//  ViewController.swift
//  CodeMirror-Swift-Example
//
//  Created by Nghia Tran on 4/29/20.
//  Copyright © 2020 Nghia Tran. All rights reserved.
//

import Cocoa
import CodeMirror

final class ViewController: NSViewController {

    private lazy var codeMirrorView = CodeMirrorWebView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        renderExample()
    }
}

extension ViewController {

    private func setup() {
        codeMirrorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(codeMirrorView)
        codeMirrorView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        codeMirrorView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        codeMirrorView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        codeMirrorView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    private func renderExample() {
        let url = Bundle.main.url(forResource: "data", withExtension: "json")!
        let content = try! String(contentsOf: url)
        codeMirrorView.setMimeType("application/json")
        codeMirrorView.setContent(content)
    }
}
