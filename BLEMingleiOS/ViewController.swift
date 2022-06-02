import UIKit
import CoreBluetooth

class ViewController: UIViewController, UITextViewDelegate {

    @IBOutlet var textView: UITextView!
    @IBOutlet weak var textView2: UITextView!
    var bleMingle: BLEMingle!

    @IBAction func sendData(_ sender: AnyObject) {
        let dataToSend = textView.text.data(using: String.Encoding.utf8)

        bleMingle.sendDataToPeripheral(data: dataToSend! as NSData)
        
        DispatchQueue.main.async { [self] in
            textView.text = ""
        }
    }
    
    func toggleSwitch() {
        var lastMessage = ""
        var allText = ""
        
        bleMingle.startScan()
        
        let dispatchQueue = DispatchQueue.global(qos: .background)
        dispatchQueue.async {
            while (true)
            {
                let temp:String = self.bleMingle.lastString as String
                if (temp != lastMessage && temp != "")
                {
                    DispatchQueue.main.async {
                        allText = allText + temp
                        self.updateView(allText)
                    }
                    lastMessage = temp
                }
                
            }
        }
    }

    func updateView(_ message: String) { 
        textView2.text = message
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.autocorrectionType = .no
        textView2.autocorrectionType = .no

        bleMingle = BLEMingle()
        textView.delegate = self
        textView.backgroundColor = .gray
        textView.textColor = .white
        
        textView.text = ""

        let delay = 2.0
        let time = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: time) {
            self.toggleSwitch()
        }

    }

    override func viewDidAppear(_ animated: Bool) {
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
