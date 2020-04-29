<img alt="GitHub" width="80%" src="https://raw.githubusercontent.com/ProxymanApp/CodeMirror-Swift/master/screenshots/logo.png">

CodeMirror-Swift is a lightweight wrapper of CodeMirror for macOS and iOS.

<img alt="screenshot" src="https://github.com/ProxymanApp/CodeMirror-Swift/blob/master/screenshots/screenshot.png">


<img alt="GitHub" src="https://img.shields.io/github/license/ProxymanApp/CodeMirror-Swift">

### Features
- 🍭 Lightweight CodeMirror wrapper (build 5.52.2)
- ✅ 100% Native Swift and WKWebView
- 🎧 Built-in addons
- 🔎 Customiziable (Addon, Themes, Modes...)
- ⚡️ Ready to go

### How to use?
1. Manually integrate `CodeMirrorWebView.swift` and `CodeMirrorView.bundle` to your project.
2. Customize to fit your need on `index.html`
3. Set `mode` and `Content`
```swift
let url = Bundle.main.url(forResource: "data", withExtension: "json")!
let content = try! String(contentsOf: url)
codeMirrorView.setMimeType("application/json")
codeMirrorView.setContent(content)
```

### How to use addons?
1. Read [CodeMirror Documentation](https://codemirror.net)
2. Enable your plugins in `index.html`

### How to add new themes?
1. Download CodeMirrror themes and put it on the folder `src/CodeMirrorView.bundle/Contents/Resources/theme`
2. Load your theme in `index.html`
3. Change by using `codeMirrorView.setThemeName("material.css")`

### Credit
- CodeMirror: https://codemirror.net
- CodeMirror-minified: https://www.npmjs.com/package/codemirror-minified 
- Pierre-Olivier Latour: https://github.com/swisspol/CodeMirrorView

### License

CodeMirror-Swift is copyright 2020 Proxyman and available under RMIT license. See the LICENSE file in the project for more information.
