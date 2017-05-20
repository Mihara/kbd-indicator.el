;; kbd-indicator.el -- Switching Emacs input method on external language switch key.

;;; (C) Eugene Medvedev 2017

;;; This file is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.

;;; Author: Eugene Medvedev <rn3aoh.g@gmail.com>
;;; Keywords: dbus, input method, language

;;; Commentary:

;; This is an Ubuntu-specific way to solve an Ubuntu-specific problem:
;; When you switch languages to ones that don't use Latin letters,
;; keyboard shortcuts stop working.
;;
;; Generally, in Emacs, you want to use the internal input method anyway, but
;; then you have to remember to never switch the xkb language in Emacs, and
;; have a separate keystroke to switch it inside Emacs, which is a pain.
;;
;; This dirty hack alleviates this pain, by reaching across Dbus into Ubuntu's
;; keyboard-indicator applet and registering to listen to language change
;; events.  Upon receiving a language change event with the Emacs window
;; active, it will reset the language to language id 0 (which is presumed to
;; be English -- so that keyboard shortcuts will keep working) and toggle the
;; Emacs input method instead.
;;
;; This permits you to use Emacs' internal input method while switching it
;; with the same language switch key that you use everywhere else, and have a
;; per-buffer rather than per-application current input language.
;;
;; I don't currently have a clue how to handle more than one non-English
;; language correctly.

;; Usage:

;;   (require 'kbd-indicator)
;;
;; Enable it with Customize or with
;;
;;   (add-hook 'after-init-hook 'global-kbd-dbus-indicator-mode)
;;
;; You want to set up the input method in the usual way as well, or there will
;; be nothing to toggle:
;;
;;   (setq default-input-method 'russian-computer)

;;; Code:

(require 'dbus)

(defconst kbd-dbus-service "com.canonical.indicator.keyboard"
  "Name of the dbus service.")
(defconst kbd-dbus-path "/com/canonical/indicator/keyboard"
  "Path of the dbus service.")
(defconst kbd-dbus-interface "org.gtk.Actions")

(defvar kbd-dbus-signal-registration nil
  "Variable to keep the signal object.")

;; There is probably a dbus way to do it without calling a console command.
;; But I don't currently know what it is.
(defcustom kbd-dbus-language-reset-command
  "gsettings set org.gnome.desktop.input-sources current 0"
  "The command to reset system language to English.
The default is GNOME/Ubuntu-specific."
  :group 'kbd-dbus
  :type 'string)

;; This method of determining if Emacs is the active system window
;; was found at https://www.emacswiki.org/emacs/rcirc-dbus.el
(defun kbd-dbus-x-active-window ()
  "Return the window ID of the current active window in X.
as given by the _NET_ACTIVE_WINDOW of the root window set by the
window-manager, or nil if not able to."
       (and (eq (window-system) 'x)
            (x-window-property
             "_NET_ACTIVE_WINDOW" nil "WINDOW" 0 nil t)))

(defun kbd-dbus-frame-outer-window-id (frame)
  "Return the frame outer-window-id property, or nil if FRAME not of the correct type."
  (and (framep frame)
       (string-to-number (frame-parameter frame 'outer-window-id))))

(defun kbd-dbus-frame-x-active-window-p (frame)
  "Check if FRAME is the X active window.
Returns t if frame has focus or nil otherwise."
       (and (framep frame)
            (eq (kbd-dbus-frame-outer-window-id frame)
                (kbd-dbus-x-active-window))))

(defun kbd-dbus-alive-p ()
  "Ping the keyboard indicator service to see if it's alive."
  (dbus-ignore-errors
    (dbus-ping :session kbd-dbus-service)))

(defun kbd-dbus-get-current-state ()
  "Synchronously get the indicator's current state, i.e. language id."
  (caaar
   (nthcdr 2 (dbus-ignore-errors
               (dbus-call-method :session
                                 kbd-dbus-service
                                 kbd-dbus-path
                                 kbd-dbus-interface "Describe" "current")))))

(defun kbd-dbus-handler (arg1 arg2 arg3 arg4)
  "Keyboard change signal handler."
  ;; Ignore the signal if we're not the active window.
  (when (kbd-dbus-frame-x-active-window-p (selected-frame))
    (let
        ;; This gets us the number of current language in the ugliest way possible.
        ;; If anyone knows a smoother method, pull requests welcome.
        ((language-id
          (caaar
           (delq nil (mapcar
                      (lambda (x)
                        (when (string= (car x) "current") (cdr x)))
                      arg3)))))
      ;; The signals come in pairs. The first one indicates new language
      ;; and produces a number.
      ;; The second one gets us a nil, so we ignore it.
      (when language-id
        ;; If the language id is not 0, flip it back.
        (when (not (eq language-id 0))
          ;; Unfortunately we have to deregister ourselves while doing that,
          ;; to avoid triggering again and looping.
          ;; Dbus signals get queued, while we execute synchronously,
          ;; so we can't just set a flag, and we don't have a way
          ;; to know where the language change event came from.
          (kbd-dbus-unregister-signal)
          (shell-command-to-string kbd-dbus-language-reset-command)
          (kbd-dbus-register-signal))
        ;; Toggle the input method.
        (toggle-input-method)))))

(defun kbd-dbus-register-signal ()
  "Register the handler to listen on language change signal."
  (unless kbd-dbus-signal-registration
    (when (kbd-dbus-alive-p)
      (setq kbd-dbus-signal-registration
            (dbus-ignore-errors
              (dbus-register-signal :session kbd-dbus-service
                                    kbd-dbus-path
                                    kbd-dbus-interface
                                    "Changed" 'kbd-dbus-handler :eavesdrop)))
      (add-hook 'kill-emacs-hook 'kbd-dbus-unregister-signal))))

(defun kbd-dbus-unregister-signal ()
  "Unregister a previously registered signal."
  (when kbd-dbus-signal-registration
    (dbus-unregister-object kbd-dbus-signal-registration)
    (setq kbd-dbus-signal-registration nil)))

;;;###autoload
(define-minor-mode kbd-dbus-indicator-mode
  "Toggle kbd-dbus-indicator mode.

Minor mode to intercept language change events emitted by
Ubuntu's keyboard-indicator and use the Emacs' built-in input
method switching instead."

  :init-value nil
  :group 'kbd-dbus
  :require 'kbd-indicator

  (if (getenv "DBUS_SESSION_BUS_ADDRESS")
      ;; Then hook up the signal.
      (kbd-dbus-register-signal)

    (message "To get at DBus, we require the environment variable
DBUS_SESSION_BUS_ADDRESS to be set, passing us the DBus socket.
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
