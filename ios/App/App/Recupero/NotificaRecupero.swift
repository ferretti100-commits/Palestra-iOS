import Foundation
import UserNotifications

// Programma e cancella la notifica di fine recupero.
// La notifica la tiene il sistema: parte all'ora giusta anche se
// l'app è chiusa o il telefono è bloccato, e col telefono bloccato
// arriva anche sull'Apple Watch.

enum NotificaRecupero {
    static let id = "fine-recupero"

    static func programma(fraSecondi secondi: Double, conSuono: Bool = true) {
        guard secondi >= 1 else { return }
        let contenuto = UNMutableNotificationContent()
        contenuto.title = "Recupero finito"
        contenuto.body = "Tocca alla prossima serie 💪"
        // Col bip acceso il suono lo fa l'app (BipRecupero), qui solo l'avviso.
        contenuto.sound = conSuono ? .default : nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondi, repeats: false)
        let richiesta = UNNotificationRequest(identifier: id, content: contenuto, trigger: trigger)
        let centro = UNUserNotificationCenter.current()
        centro.removePendingNotificationRequests(withIdentifiers: [id])
        centro.add(richiesta)
    }

    static func cancella() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
