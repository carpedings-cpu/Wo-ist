import UIKit
import Capacitor
import Speech
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// MARK: - Wo ist's? · Autorin: Diana Ziegler

/// Startet die Web-App und meldet das Sprach-Plugin an.
class WoIstViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(SprachePlugin())
    }
}

/// Spracheingabe auf Deutsch. Hört zu, bis 1,5 Sekunden Stille sind, und liefert den Satz.
@objc(SprachePlugin)
public class SprachePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SprachePlugin"
    public let jsName = "Sprache"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "verfuegbar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hoeren", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "abbrechen", returnType: CAPPluginReturnPromise)
    ]

    private let erkenner = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let motor = AVAudioEngine()
    private var anfrage: SFSpeechAudioBufferRecognitionRequest?
    private var aufgabe: SFSpeechRecognitionTask?
    private var stilleTimer: Timer?
    private var offenerAufruf: CAPPluginCall?
    private var letzterText = ""

    @objc func verfuegbar(_ call: CAPPluginCall) {
        call.resolve(["verfuegbar": erkenner?.isAvailable ?? false])
    }

    @objc func hoeren(_ call: CAPPluginCall) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                call.reject("Spracherkennung nicht erlaubt", "not-allowed")
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { erlaubt in
                DispatchQueue.main.async {
                    guard erlaubt else {
                        call.reject("Mikrofon nicht erlaubt", "not-allowed")
                        return
                    }
                    self.starte(call)
                }
            }
        }
    }

    @objc func abbrechen(_ call: CAPPluginCall) {
        if let offen = offenerAufruf {
            offenerAufruf = nil
            offen.resolve(["text": "", "abgebrochen": true])
        }
        beende()
        call.resolve()
    }

    private func starte(_ call: CAPPluginCall) {
        beende()
        guard let erkenner = erkenner, erkenner.isAvailable else {
            call.reject("Spracherkennung nicht verfügbar", "service-not-allowed")
            return
        }
        do {
            let sitzung = AVAudioSession.sharedInstance()
            try sitzung.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try sitzung.setActive(true, options: .notifyOthersOnDeactivation)

            let neu = SFSpeechAudioBufferRecognitionRequest()
            neu.shouldReportPartialResults = true
            if erkenner.supportsOnDeviceRecognition {
                neu.requiresOnDeviceRecognition = true
            }
            anfrage = neu

            let eingang = motor.inputNode
            eingang.installTap(onBus: 0, bufferSize: 1024, format: eingang.outputFormat(forBus: 0)) { puffer, _ in
                neu.append(puffer)
            }
            motor.prepare()
            try motor.start()

            offenerAufruf = call
            letzterText = ""
            planeEnde(nach: 8)

            aufgabe = erkenner.recognitionTask(with: neu) { [weak self] ergebnis, fehler in
                DispatchQueue.main.async {
                    guard let self = self, self.offenerAufruf != nil else { return }
                    if let ergebnis = ergebnis {
                        self.letzterText = ergebnis.bestTranscription.formattedString
                        self.notifyListeners("teilergebnis", data: ["text": self.letzterText])
                        if ergebnis.isFinal {
                            self.fertig()
                        } else {
                            self.planeEnde(nach: 1.5)
                        }
                    } else if fehler != nil {
                        self.fertig()
                    }
                }
            }
        } catch {
            beende()
            call.reject("Mikrofon nicht nutzbar", "audio-capture")
        }
    }

    private func planeEnde(nach sekunden: TimeInterval) {
        stilleTimer?.invalidate()
        stilleTimer = Timer.scheduledTimer(withTimeInterval: sekunden, repeats: false) { [weak self] _ in
            self?.fertig()
        }
    }

    private func fertig() {
        guard let call = offenerAufruf else { return }
        offenerAufruf = nil
        let text = letzterText
        beende()
        call.resolve(["text": text])
    }

    private func beende() {
        stilleTimer?.invalidate()
        stilleTimer = nil
        if motor.isRunning {
            motor.stop()
        }
        motor.inputNode.removeTap(onBus: 0)
        anfrage?.endAudio()
        anfrage = nil
        aufgabe?.cancel()
        aufgabe = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
