import AVFoundation
import Foundation

// Il bip di fine recupero, suonato dall'app e non dalla pagina.
// Così si sente anche col telefono in silenzioso, bloccato o mentre
// sei su un'altra app. Quando suona, la musica si abbassa per il tempo
// del bip e poi torna al suo volume.
//
// Come funziona: finché il recupero va, l'app tiene aperto l'audio con
// un suono muto che si mescola alla musica, senza fermarla. È quello che
// permette all'app di restare sveglia col telefono bloccato. A fine
// recupero l'audio si riaccende con la musica abbassata, suona il bip
// e poi l'app rilascia l'audio e la musica torna su.

@MainActor
enum BipRecupero {
    private static var muto: AVAudioPlayer?
    private static var bip: AVAudioPlayer?
    private static var attesa: Task<Void, Never>?
    private static var fineAttesa: Date?

    static func programma(fraSecondi secondi: Double) {
        guard secondi >= 1 else { return }
        let fine = Date().addingTimeInterval(secondi)
        // Stesso recupero di prima: non si ricomincia.
        if let f = fineAttesa, attesa != nil, abs(f.timeIntervalSince(fine)) < 1.5 { return }
        annulla(rilasciaAudio: false)

        let sessione = AVAudioSession.sharedInstance()
        try? sessione.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? sessione.setActive(true)
        muto = try? AVAudioPlayer(data: Suoni.silenzio)
        muto?.numberOfLoops = -1
        muto?.play()

        fineAttesa = fine
        attesa = Task { @MainActor in
            try? await Task.sleep(for: .seconds(secondi))
            if Task.isCancelled { return }
            suona()
        }
    }

    static func annulla(rilasciaAudio: Bool = true) {
        attesa?.cancel()
        attesa = nil
        fineAttesa = nil
        muto?.stop()
        muto = nil
        if rilasciaAudio {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private static func suona() {
        attesa = nil
        fineAttesa = nil

        let sessione = AVAudioSession.sharedInstance()
        // Si spegne e si riaccende l'audio MENTRE il suono muto va ancora:
        // così iOS considera l'app ancora "in riproduzione" e lascia
        // riaccenderlo anche col telefono bloccato.
        try? sessione.setActive(false)
        // Musica abbassata durante il bip ("duck"), poi torna al suo volume.
        try? sessione.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
        do {
            try sessione.setActive(true)
        } catch {
            // Se iOS non lascia abbassare la musica, il bip suona lo stesso sopra.
            try? sessione.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        bip = try? AVAudioPlayer(data: Suoni.bip)
        bip?.volume = 1
        bip?.play()

        // Finito il bip si spegne l'audio avvisando le altre app,
        // così la musica torna al volume di prima.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            bip = nil
            muto?.stop()
            muto = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

// I suoni, creati al volo: niente file da aggiungere al progetto.
private enum Suoni {
    static let frequenza = 44_100

    // Un secondo di silenzio, ripetuto mentre il recupero va.
    static let silenzio: Data = wav(campioni: [Int16](repeating: 0, count: frequenza))

    // Tre toni corti e acuti, "bip-bip-bip", come quelli dell'app sul web.
    static let bip: Data = {
        let durata = 0.6
        var campioni = [Int16](repeating: 0, count: Int(Double(frequenza) * durata))
        let toni: [(inizio: Double, freq: Double)] = [(0, 1568), (0.18, 1568), (0.36, 2093)]
        for tono in toni {
            let da = Int(tono.inizio * Double(frequenza))
            let lunghezza = Int(0.14 * Double(frequenza))
            for i in 0..<lunghezza where da + i < campioni.count {
                let t = Double(i) / Double(frequenza)
                // Onda quadra, ammorbidita all'inizio e alla fine.
                let onda: Double = sin(2 * .pi * tono.freq * t) >= 0 ? 1 : -1
                let attacco = min(1, t / 0.01)
                let rilascio = min(1, (0.14 - t) / 0.03)
                let valore = onda * 0.45 * attacco * max(0, rilascio)
                campioni[da + i] = Int16(valore * Double(Int16.max))
            }
        }
        return wav(campioni: campioni)
    }()

    static func wav(campioni: [Int16]) -> Data {
        var d = Data()
        func scrivi<T: FixedWidthInteger>(_ v: T) { var x = v.littleEndian; d.append(Data(bytes: &x, count: MemoryLayout<T>.size)) }
        let byteDati = UInt32(campioni.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); scrivi(UInt32(36) + byteDati)
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); scrivi(UInt32(16)); scrivi(UInt16(1)); scrivi(UInt16(1))
        scrivi(UInt32(frequenza)); scrivi(UInt32(frequenza * 2)); scrivi(UInt16(2)); scrivi(UInt16(16))
        d.append(contentsOf: Array("data".utf8)); scrivi(byteDati)
        for c in campioni { scrivi(c) }
        return d
    }
}
