;;; Set line numbers on left side
(global-display-line-numbers-mode t)

;;; Set line and column numbering in mode line
(line-number-mode t)
(column-number-mode t)

;;; Set visual feedback on selections
(setq-default transient-mark-mode t)

;;; Set region replacement just by typing text
(delete-selection-mode t)

;;; Set standard indent to 4 rather that 8
(setq default-tab-width 4)

;;; Show matching parentecies
(show-paren-mode 1)

;;; Unset the line wrapping
(setq-default truncate-lines t)
(setq truncate-partial-width-windows nil)

;;; Add a newline at end of file (if required)
(setq require-final-newline t)

;;; Replace 'yes' and 'no' with 'y' and 'n' for questions
(defalias 'yes-or-no-p 'y-or-n-p)

;;; Place backup files in specific directory
(setq make-backup-files t)
(setq version-control t)
(setq kept-old-versions 2)
(setq kept-new-versions 5)
(setq backup-directory-alist (quote ((".*" . "~/.emacs_backups/"))))
(setq delete-old-versions t)

;;; What kind of system are we using?
(if (eq (symbol-value 'window-system) nil)
    ;;; Console
    (progn
      )
  ;;; GUI
  (progn
    ;;; Set window decoration setting
    (setq inhibit-startup-screen t)

    ;;; Unset toolbar
    (tool-bar-mode -1)

    ;;; Set Look and Feel
    (set-background-color "DarkSlateGray")
    (set-foreground-color "Wheat")
    (set-cursor-color "Orchid")
    (set-mouse-color "Orchid")
    ;;(set-default-font "Lucida Console")
    ;;(set-face-attribute 'default nil :height 130)

    ;;; Unset anti-aliasing font
    (setq mac-allow-anti-aliasing nil)

    ;;; Set the highlight current line minor mode
    (global-hl-line-mode t)

    ;;; Set Option-key as Meta-key
    (setq mac-option-modifier 'meta)
    )
  )

;;; Set C++ mode on files
(setq auto-mode-alist (cons '("\\.h\\'" . c++-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("\\.i\\'" . c++-mode) auto-mode-alist))
(c-set-offset 'innamespace 0)
(c-set-offset 'defun-open 0)
(c-set-offset 'defun-close 0)
(c-set-offset 'substatement-open 0)
(c-set-offset 'statement-case-open 0)
;;(set-face-foreground 'font-lock-comment-face "red")
;;(set-face-foreground 'font-lock-comment-delimiter-face "red")

;;; Set SCons mode on files
(setq auto-mode-alist (cons '("SConstruct$" . python-mode) auto-mode-alist))
(setq auto-mode-alist (cons '("SConscript$" . python-mode) auto-mode-alist))

;;; Set keyboard shortcuts
;;(global-set-key [home] 'beginning-of-line)
;;(global-set-key [end] 'end-of-line)
;;(global-set-key [\C-home] 'beginning-of-buffer)
;;(global-set-key [\C-end] 'end-of-buffer)
;;(global-set-key "\C-a" 'mark-whole-buffer)
;;(global-set-key (kbd "C-c c") 'comment-region)
;;(global-set-key (kbd "C-c u") 'uncomment-region)
;;(global-set-key [f4] 'clang-format-buffer)
(global-set-key [f5] 'whitespace-mode)
(global-set-key [f6] 'toggle-truncate-lines)
(global-set-key [f7] 'delete-trailing-whitespace)
;;(global-set-key [f8] 'next-error)

;;; Set automatic pair for (, [ and {
;;(setq skeleton-pair t)
;;(setq skeleton-pair-on-word t)
;;(global-set-key (kbd "(") 'skeleton-pair-insert-maybe)
;;(global-set-key (kbd "[") 'skeleton-pair-insert-maybe)
;;(global-set-key (kbd "{") 'skeleton-pair-insert-maybe)
;;(add-hook 'c-mode-common-hook
;;  (lambda ()
;;    (local-set-key "(" 'skeleton-pair-insert-maybe)
;;    (local-set-key "{" 'skeleton-pair-insert-maybe)
;;  )
;;)

;;; Set MELPA package repository
(require 'package)
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
;;(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;;; Set Flyspell for spell checking
(dolist (hook '(text-mode-hook))
  (add-hook hook (lambda () (flyspell-mode 1))))
