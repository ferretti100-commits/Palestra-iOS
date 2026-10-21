import Capacitor
import UIKit
import WebKit

// Il controller dell'app iPhone: è quello di Capacitor, con in più gli
// script del recupero (ScriptPagina) e chi riceve i loro messaggi.
class PalestraViewController: CAPBridgeViewController {
    private let ricevitore = RicevitorePagina()

    override func webViewConfiguration(for instanceConfiguration: InstanceConfiguration) -> WKWebViewConfiguration {
        let config = super.webViewConfiguration(for: instanceConfiguration)
        let contenuto = config.userContentController
        contenuto.addUserScript(WKUserScript(source: ScriptPagina.senzaBipPagina,
                                             injectionTime: .atDocumentStart,
                                             forMainFrameOnly: true))
        contenuto.addUserScript(WKUserScript(source: ScriptPagina.recupero,
                                             injectionTime: .atDocumentEnd,
                                             forMainFrameOnly: true))
        contenuto.add(ricevitore, name: "recupero")
        return config
    }
}

// I messaggi dello script del recupero: notifica, bip, notch e schermata di blocco.
@MainActor
final class RicevitorePagina: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let dati = message.body as? [String: Any],
              let azione = dati["azione"] as? String else { return }
        if azione == "programma", let numero = dati["secondi"] as? NSNumber {
            let secondi = numero.doubleValue
            let accento = dati["accento"] as? String ?? ""
            var inizioAllenamento: Date? = nil
            if let durata = dati["durataAllenamento"] as? NSNumber {
                inizioAllenamento = Date().addingTimeInterval(-durata.doubleValue)
            }
            let bip = (dati["bip"] as? Bool) ?? false
            NotificaRecupero.programma(fraSecondi: secondi, conSuono: !bip)
            if bip {
                BipRecupero.programma(fraSecondi: secondi)
            } else {
                BipRecupero.annulla()
            }
            RecuperoLive.avvia(fraSecondi: secondi, accento: accento,
                               nomeAllenamento: dati["nomeAllenamento"] as? String ?? "",
                               esercizio: dati["esercizio"] as? String ?? "",
                               serie: dati["serie"] as? String ?? "",
                               inizioAllenamento: inizioAllenamento)
        } else if azione == "cancella" {
            NotificaRecupero.cancella()
            BipRecupero.annulla()
            RecuperoLive.ferma()
        }
    }
}
