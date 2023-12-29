;;; benchmark_and_compare.template.el ---            -*- lexical-binding: t; -*-

;; (setq gc-cons-threshold (* 32 (* 1024 1024))
;;       gc-cons-percentage 0.1)

;; disable GC
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(defun -all (fn elems)
  (let ((n (length elems))
        (all-vals (mapcar (lambda (x) (if (funcall fn x) 1 0)) elems)))
    (equal n (apply '+ all-vals))))

(defun -plist-to-sorted-alist (p)
  (let (res)
    (while p
      (push (cons (car p) (cadr p)) res)
      (setq p (cddr p)))
    (sort res (lambda (a b) (string< (symbol-name (car a)) (symbol-name (car b)))))))

(defun json-equal (a b)
  (pcase a
    ((or
      (pred numberp)
      (pred symbolp)
      (pred stringp)
      'nil
      't)
     (equal a b))
    ((pred vectorp)
     (and (vectorp b)
          (equal (length a) (length b))
          (-all (lambda (idx) (json-equal (aref a idx) (aref b idx)))
                 (number-sequence 0 (1- (length a))))))
    ((pred plistp)
     (and (plistp b)
          (equal (length a) (length b))
          (let ((a-alist (-plist-to-sorted-alist a))
                (b-alist (-plist-to-sorted-alist b))
                (res t))
            (while a-alist
              (unless (and (equal (caar a-alist) (caar b-alist))
                           (json-equal (cdar a-alist) (cdar b-alist)))
                (setq res nil))
              (setq a-alist (cdr a-alist)
                    b-alist (cdr b-alist)))
            res)))
    (_ nil)))

(let ((json-str (with-temp-buffer
                  (insert-file-contents "{}")
                  (buffer-string)))
      (bytecode-str (with-temp-buffer
                      (insert-file-contents "{}")
                      (buffer-string)))
      json-val bytecode-val)
  (unless (json-equal (setq json-val
                            (json-parse-string json-str :object-type 'plist :null-object nil :false-object nil))
                      (setq bytecode-val
                            (funcall (read bytecode-str))))
    (error "NOT EQUAL!"))
  (message "Benchmark json-parse-string 100 times: %s"
           (benchmark-run 100
             (json-parse-string json-str :object-type 'plist :null-object nil :false-object nil)))
  (message "Benchmark read-eval-bytecode 100 times: %s"
           (benchmark-run 100
             (funcall (read bytecode-str))))
  (let ((lisp-str (prin1-to-string json-val)))
    (message "Benchmark read-lisp-data 100 times: %s"
             (benchmark-run 100
               (read lisp-str))))
  
  (message "PASS!"))
