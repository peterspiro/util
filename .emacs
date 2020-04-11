; Default .emacs file for new users.
;
;;; xwindows
(if (symbolp window-system-version)
    ()                                  ; ignore if no window system in use
  (if (and (= 11 window-system-version) ; check which window system
           (string-equal (substring emacs-version 0 2) "18"))
      (progn
        (load-library "x-mouse")        ; X11 settings

        (defun x-mouse-set-mark-cut-copy (arg)
          "Set mark to define a region.
        Cut [for X] and copy-as-kill [for emacs] the text in the region."
          (progn
            (x-mouse-set-mark arg)
            (x-cut-text arg)))

        (defun x-mouse-set-mark-cut-kill (arg)
          "Set mark to define a region.
        Cut [for X] and kill [for emacs] the text in the region."
          (progn (x-mouse-set-mark arg) (x-cut-and-wipe-text arg)))

        (define-key mouse-map x-button-left 'x-mouse-set-point)
        (define-key mouse-map x-button-middle 'x-paste-text)
        (define-key mouse-map x-button-right 'x-mouse-set-mark-cut-copy)
        (define-key mouse-map x-button-s-left 'x-mouse-set-point)
        (define-key mouse-map x-button-s-middle 'x-paste-text)
        (define-key mouse-map x-button-s-right 'x-mouse-set-mark-cut-kill))))

;;;;;;;;; end of x-mouse stuff i think ;;;;;;;;;;;;;

(autoload 'gnus "gnus" "Read network news." t)
(autoload 'gnus-post-news "gnuspost" "Post a news." t)
;(setq x-set-font "courier18")

(autoload 'S "S" "Run an inferior S process" t)
(autoload 's-mode "S" "Mode for editing S source" t)

(setq text-mode-hook
      '(lambda ()
         (auto-fill-mode 1)
         ))

(setq vip-mode-hook
      '(lambda ()
         (auto-fill-mode 1)
         ))

(setq fundamental-mode-hook
      '(lambda ()
         (auto-fill-mode 1)
         ))

(setq latex-mode-hook
      '(lambda ()
(defun update-LaTeX-bibtags ("~/.dumaux"))
         (auto-fill-mode 1)
         ))

(setq fortran-mode-hook
      '(lambda ()
         (abbrev-mode 1)
         ))

(defun vip-mode ()
  (vip-change-mode-to-vi)
  (run-hooks 'vip-mode-hook))

(setq term-setup-hook 'vip-mode)
(load "vip")
;(setq auto-fill-mode t)
;(setq abbrev-mode t)

(setq auto-mode-alist
      (cons (cons "\\.sf3$" 'fortran-mode) auto-mode-alist))

;=======================================================================

(setq transient-mark-mode nil)

;=======================================================================
;;; Add bibtex mode unconditionally; it is already bound to text-mode
;;; and we can do better than that.
(delq (assoc "\\.bib$" auto-mode-alist) auto-mode-alist)
(setq auto-mode-alist
      (cons (cons "\\.bib$" 'bibtex-mode) auto-mode-alist))
(autoload 'bibtex-mode  "bibtex"
  "Enter BibTeX mode for bibliography editing." t nil)

(setq bibtex-mode-hook
      '(lambda ()
         (setq bibtex-include-OPTannote nil)
         (setq bibtex-include-OPTcrossref nil)
         (setq bibtex-include-OPTkey nil)
         (setq indent-tabs-mode nil)
         (local-set-key "\C-cn" 'bibtex-normalize-entries) ; temporary
         (local-set-key "\C-cp" 'bibtex-prettyprint-buffer) ; temporary
         (local-set-key "\C-cv" 'bibtex-validate-buffer) ; temporary
         (setq comment-end "")
         (setq comment-start "%% ")
         (setq comment-start-skip "%+ *")
         (if (and (boundp 'window-system)
                  (equal window-system 'x)
                  (not (boundp 'epoch::version)))
             (bibtex-x-environment))    ; turn on X menus under X windows
         (if (boundp 'defmenu)
             (load (concat "~beebe/emacs/nbibtex") t t nil))
                                        ; newer version of bibtex.el
                                        ; [28-Jun-1990]
         (load (concat "~beebe/emacs/bibtex-mods") t t nil)
                                        ; enhancements to bibtex mode
         ;;(load "sun-mouse" t t nil)   ; need for defmenu in bibtex.el
         ;;(load (concat "~beebe/emacs/bibtex") t t nil)
                                        ; new version of bibtex.el
         ;;(load (concat "~beebe/emacs/new-bibtex") t t nil)
                                        ; newest BibTeX support [09-Nov-1991]
         ))

(defvar quote-region-prefix ">> "
  "String to insert in front of lines quoted by quote-region.")
(global-set-key "\C-c>" 'quote-region)

(defun quote-region ()
  "Insert '>> ' in front of each line in the region,
 usually for mail quoting.  The inserted string can be customized by
 setting it from the variable quote-region-prefix."
  (interactive)
  (narrow-to-region (mark) (point))
  (goto-char (point-min))
  (insert "\n" quote-region-prefix "...\n")
  (while (< (point) (point-max))
    (insert quote-region-prefix)
    (forward-line 1))
  (if (not (looking-at "$"))
      (newline))
  (insert quote-region-prefix "...\n\n")
  (widen))

(global-font-lock-mode 1)

;; put find-recursive.el in the following directory:
;(setq load-path (cons "~/emacs/lisp/" load-path))
;(setq load-path (cons "y:\\" load-path))
;(require 'find-recursive)

(setq load-path (cons "~/emacs/lisp/ruby-mode/" load-path))

;;; (1) modify .emacs to use ruby-mode
(autoload 'ruby-mode "ruby-mode"
  "Mode for editing ruby source files" t)
(setq auto-mode-alist
      (append '(("\\.rb$" . ruby-mode)) auto-mode-alist))
(setq interpreter-mode-alist (append '(("ruby" . ruby-mode))
                              interpreter-mode-alist))
;;;
;;; (2) set to load inf-ruby and set inf-ruby key definition in ruby-mode.
;;;
(autoload 'run-ruby "inf-ruby"
  "Run an inferior Ruby process")
(autoload 'inf-ruby-keys "inf-ruby"
  "Set local key defs for inf-ruby in ruby-mode")
(add-hook 'ruby-mode-hook
      '(lambda ()
         (inf-ruby-keys)
))
;;;


(setq load-path (cons "~/pair_tar/emacs/lisp/" load-path))
(autoload 'html-helper-mode "html-helper-mode" "Yay HTML" t)
(setq auto-mode-alist (cons '("\\.html?" . html-helper-mode) auto-mode-alist))

(global-set-key "\C-z" 'vip-change-mode-to-vi)

(setq-default indent-tabs-mode nil)

(defun my-java-mode-hook ()
  (setq c-basic-offset 3))
(add-hook 'java-mode-hook 'my-java-mode-hook)


; https://stackoverflow.com/questions/9985316/how-to-paste-to-emacs-from-clipboard-on-osx/9986416

(defun copy-from-osx ()
(shell-command-to-string "pbpaste"))

(defun paste-to-osx (text &optional push)
(let ((process-connection-type nil))
(let ((proc (start-process "pbcopy" "*Messages*" "pbcopy")))
(process-send-string proc text)
(process-send-eof proc))))

(setq interprogram-cut-function 'paste-to-osx)
(setq interprogram-paste-function 'copy-from-osx)
