//
//  FactorialViewController.swift
//  vidQR
//
//  Created by Noah Sadir on 3/31/21.
//

import UIKit

class FactorialViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let 🎬 = -3
        let 🏁 = 8

        //🔄 🎬➡️🏁  🤔🧮🔄🧠💡  ➡️  🖨
        for 🧐 in 🎬...🏁 {
            🖨(📝:🤔🧮🔄🧠💡(🤓: 🧐))
        }
    }

    // 📬 🧵 🧮 #️⃣❗️
    func 🤔🧮🔄🧠💡(🤓: Int) -> String {
        var 📈 = 1
        
        //🤔 #️⃣➡️2️⃣🔼
        if 🤓 >= 2 {
            //🔄 2️⃣➡️🤓 🧮 ❗️
            for 🥰 in 2...🤓 {
                📈 = 📈 * 🥰
            }
        }
        
        //🤔 #️⃣0️⃣🔼❓ ✅➡️😁  ❌➡️😡
        if 🤓 >= 0 {
            //#️⃣❗️ ✅🧮  ➡️  #️⃣0️⃣🔼 📬 🧵 👍
            return "😁👍 ✅🧮 " + 🧵(🧮:🤓) + "❗️ 🏁#️⃣ " + 🧵(🧮:📈)
        } else {
            //#️⃣❗️ ❌🧮  ➡️  #️⃣⬇️0️⃣ 📬 🧵 👎
            return "😡👎 ❌🧮 " + 🧵(🧮:🤓) + "❗️"
        }
    }

    func 🧵(🧮: Int) -> String {
        return String(🧮)
    }

    func 🖨(📝: String) {
        print(📝)
    }



}
