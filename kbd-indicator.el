;; kbd-indicator.el -- Switching Emacs input method on external language switch key.

;;; (C) Eugene Medvedev 2017-2022

;;; This file is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.

;;; Author: Eugene Medvedev <rn3aoh.g@gmail.com>
;;; Keywords: dbus, input method, language

;;; Commentary:

;; This is an Ubuntu-specific way to solve an Ubuntu-specific problem: When you
;; switch languages to ones that don't use Latin letters, keyboard shortcuts
;; stop working.  It may or may not work in other systems based on Gnome Shell.
;; The name comes from originally relying on Unity and keyboard-indicator.
;;
;; Generally, in Emacs, you want to use the internal input method anyway, but
;; then you have to remember to never switch the system language in Emacs, and
;; have a separate keystroke to switch it inside Emacs, which is a pain.
;;
;; This dirty hack alleviates this pain, by listening to Dbus events emitted
;; when you switch languages.  Upon receiving one while the Emacs window is
;; active, it will reset the language to English (so that keyboard shortcuts
;; will keep working) and toggle the Emacs input method instead.
;;
;; This permits you to use Emacs' internal input method while switching it with
;; the same language switch key that you use everywhere else, and have a
;; per-buffer rather than per-application current input language.
;;
;; I don't currently have a clue how to handle more than one non-English
;; language correctly.  The language to avoid, however, can be customized.
;;
;; Requires Emacs 27.1 or newer.

;; Usage:

;;   (require 'kbd-indicator)
;;
;; Enable it with Customize or with
;;
;;   (add-hook 'after-init-hook 'global-kbd-dbus-indicator-mode)
;;
;; If you use a language other than Russian that suffers from this problem, you
;; can customize the language code.
;;
;; You want to set up the input method in the usual way as well, or there will
;; be nothing to toggle:
;;
;;   (setq default-input-method 'russian-computer)

;;; Code:

(require 'dbus)

(defgroup kbd-indicator nil "Kbd-indicator configuration."
  :group 'languages)

(defcustom avoidance-language "ru"
  "The language code to switch out of."
  :type 'string
  :group 'kbd-indicator)

(defvar kbd-dbus-signal-registration nil
  "Variable to keep the signal object.")

(defun kbd-dbus-reset-to-english ()
  "Reset keyboard to English by sending a dbus message."
  ;; This is kind of an insane way to do it, but works well: we're essentially
  ;; telling Gnome Shell to run javascript that will flip the keyboard
  ;; language.  This is equivalent to

  ;; gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell
  ;; --method org.gnome.Shell.Eval
  ;; "imports.ui.status.keyboard.getInputSourceManager().inputSources[0].activate()"

  ;; Yes, we are assuming English is language 0 and hardcoding it.

  (dbus-call-method-asynchronously
   :session
   "org.gnome.Shell"
   "/org/gnome/Shell"
   "org.gnome.Shell"
   "Eval"
   nil
   (concat "imports.ui.status.keyboard.getInputSourceManager()"
           ".inputSources[0].activate()")))

(defun kbd-dbus-handler-new (group setting value)
  "Language change signal handler."
  (when (eq (frame-focus-state) t)
    (when (and
           (equal group "org.gnome.desktop.input-sources")
           (equal setting "mru-sources"))
      ;; What we get here is a structure like

      ;; ((("xkb" "<language code>") ("xkb" "ru")))

      ;; where `language code' is the language last switched to, either 'ru' or
      ;; 'us' in my case.
      (let ((language-id (cadr (caar value))))
        ;; With this input signal and language switching method, we don't get
        ;; an event when we force the language back to English.  This makes
        ;; things magnitudes easier than they were with keyboard-indicator: if
        ;; the language we switched into is the one we're avoiding, flip it
        ;; back. Then toggle the input method.
        (when (equal language-id avoidance-language)
          (kbd-dbus-reset-to-english))
        (toggle-input-method))
      )))


(defun kbd-dbus-register-signal ()
  "Register the handler to listen on language change signal."
  (unless kbd-dbus-signal-registration
    (setq kbd-dbus-signal-registration
          (dbus-ignore-errors
            (dbus-register-signal
             :session
             nil ;; dbus service is nil - this is a broadcast signal.
             "/org/freedesktop/portal/desktop" ;; path
             "org.freedesktop.impl.portal.Settings" ;; interface
             "SettingChanged" ;; signal - method name, that is.
             'kbd-dbus-handler-new :eavesdrop)))
    (add-hook 'kill-emacs-hook 'kbd-dbus-unregister-signal)))

(defun kbd-dbus-unregister-signal ()
  "Unregister a previously registered signal."
  (when kbd-dbus-signal-registration
    (dbus-unregister-object kbd-dbus-signal-registration)
    (setq kbd-dbus-signal-registration nil)))

;;;###autoload
(define-minor-mode kbd-dbus-indicator-mode
  "Toggle kbd-dbus-indicator mode.

Minor mode to intercept language change events emitted by Gnome \
Shell and use the Emacs' built-in input method switching \
instead."

  :init-value nil
  :group 'kbd-dbus
  :require 'kbd-indicator

  (if (getenv "DBUS_SESSION_BUS_ADDRESS")
      ;; Then hook up the signal.
      (kbd-dbus-register-signal)
    (message "To get at DBus, we require the environment variable \
DBUS_SESSION_BUS_ADDRESS to be set, passing us the DBus socket. \
It is not set. Indicator-based language switching will not work.")
    (global-kbd-dbus-indicator-mode -1)))

;;;###autoload
(define-globalized-minor-mode global-kbd-dbus-indicator-mode
  kbd-dbus-indicator-mode
  kbd-dbus-indicator-mode
  :group 'kbd-dbus
  :require 'kbd-indicator)

(provide 'kbd-indicator)
;;; kbd-indicator.el ends here
