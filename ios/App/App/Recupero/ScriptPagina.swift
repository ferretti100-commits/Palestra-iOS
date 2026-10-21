import Foundation

// Gli script che l'app iPhone aggiunge alla pagina. Il codice del sito non
// si tocca: l'app guarda la pagina dall'esterno.
enum ScriptPagina {

    // Guarda la card del recupero ogni mezzo secondo e, quando il timer sta
    // andando, dice all'app tra quanti secondi finisce, con nome
    // dell'allenamento, esercizio, serie, tempo totale, colore d'accento e
    // campanella. In pausa, al reset o a recupero finito dice di cancellare.
    // Dipende da questi nomi del sito: .recupero-striscia, il tasto con
    // aria-label "Pausa", .recupero-numero (.oltre), .sessione-testa-nome,
    // .sessione-testa-sub, .pista-esercizi .card:not(.non-attiva) con
    // .ex-head e .serie-ora-testa, e la chiave palestra:bip:v1.
    static let recupero = #"""
(function () {
  var fineInviata = null;
  function manda(msg) {
    try { window.webkit.messageHandlers.recupero.postMessage(msg); } catch (e) {}
  }
  function leggiSecondi(testo) {
    var m = /^\s*(\d+):(\d{2})\s*$/.exec(testo || '');
    return m ? parseInt(m[1], 10) * 60 + parseInt(m[2], 10) : null;
  }
  // Il colore d'accento che l'utente ha scelto nell'app, come #rrggbb.
  function leggiAccento() {
    try {
      var el = document.createElement('span');
      el.style.color = 'var(--accent)';
      document.body.appendChild(el);
      var c = getComputedStyle(el).color;
      el.remove();
      var m = /rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(c);
      if (!m) return '';
      return '#' + [m[1], m[2], m[3]].map(function (n) {
        return ('0' + parseInt(n, 10).toString(16)).slice(-2);
      }).join('');
    } catch (e) { return ''; }
  }
  function testo(sel) {
    var el = document.querySelector(sel);
    return el ? el.textContent.replace(/\s+/g, ' ').trim() : '';
  }
  // Nome dell'allenamento, esercizio, serie e da quanti secondi dura
  // l'allenamento, letti dalla testata e dalla card dell'esercizio attivo.
  function leggiAllenamento() {
    var card = '.pista-esercizi .card:not(.non-attiva)';
    var serie = testo(card + ' .serie-ora-testa').split(' · ')[0];
    var durata = null;
    var sub = /^\s*(\d+):(\d{2})(?::(\d{2}))?/.exec(testo('.sessione-testa-sub'));
    if (sub) {
      durata = sub[3] !== undefined
        ? parseInt(sub[1], 10) * 3600 + parseInt(sub[2], 10) * 60 + parseInt(sub[3], 10)
        : parseInt(sub[1], 10) * 60 + parseInt(sub[2], 10);
    }
    return {
      nomeAllenamento: testo('.sessione-testa-nome'),
      esercizio: testo(card + ' .ex-head .grow > div:first-child'),
      serie: serie,
      durataAllenamento: durata
    };
  }
  // La campanella accesa nella card del recupero (la ricorda il sito).
  function bipAcceso() {
    try { return localStorage.getItem('palestra:bip:v1') === '1'; } catch (e) { return false; }
  }
  var infoInviate = '';
  function controlla() {
    var strisce = document.querySelectorAll('.recupero-striscia');
    var rimanenti = null;
    for (var i = 0; i < strisce.length; i++) {
      var s = strisce[i];
      if (!s.querySelector('button[aria-label="Pausa"]')) continue;
      var numero = s.querySelector('.recupero-numero');
      if (!numero || numero.classList.contains('oltre')) continue;
      var sec = leggiSecondi(numero.textContent);
      if (sec !== null && sec > 0) { rimanenti = sec; break; }
    }
    if (rimanenti === null) {
      if (fineInviata !== null) { manda({ azione: 'cancella' }); fineInviata = null; }
      return;
    }
    var fine = Date.now() + rimanenti * 1000;
    var info = leggiAllenamento();
    var bip = bipAcceso();
    var chiave = [info.nomeAllenamento, info.esercizio, info.serie, bip].join('|');
    if (fineInviata === null || Math.abs(fine - fineInviata) > 1500 || chiave !== infoInviate) {
      manda({
        azione: 'programma', secondi: rimanenti, accento: leggiAccento(),
        nomeAllenamento: info.nomeAllenamento, esercizio: info.esercizio,
        serie: info.serie, durataAllenamento: info.durataAllenamento, bip: bip
      });
      fineInviata = fine;
      infoInviate = chiave;
    }
  }
  setInterval(controlla, 500);
})();
"""#

    // Il bip della pagina si spegne: dentro l'app in silenzioso non si
    // sentirebbe e si sovrapporrebbe a quello dell'app (BipRecupero).
    // Il sito usa l'audio della pagina solo per quel bip.
    static let senzaBipPagina = #"""
try {
  Object.defineProperty(window, 'AudioContext', { value: undefined, configurable: true, writable: true });
  Object.defineProperty(window, 'webkitAudioContext', { value: undefined, configurable: true, writable: true });
} catch (e) {}
"""#
}
