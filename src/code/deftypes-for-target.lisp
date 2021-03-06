;;;; definitions of types for the target (output of the compiler)

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.
;;;;
;;;; This software is derived from the CMU CL system, which was
;;;; written at Carnegie Mellon University and released into the
;;;; public domain. The software is in the public domain and is
;;;; provided with absolutely no warranty. See the COPYING and CREDITS
;;;; files for more information.

(in-package "SB-KERNEL")

(/show0 "deftypes-for-target.lisp 14")

;;;; Now that DEFTYPE is set up, any pending requests for it can
;;;; be honored.

#+sb-xc-host
(progn
  (/show "about to force delayed DEF!TYPEs")
  (force-delayed-def!types)
  (/show "done forcing delayed DEF!TYPEs"))

;;;; standard types

(sb-xc:deftype boolean () '(member t nil))

(sb-xc:deftype mod (n)
  (unless (and (integerp n) (> n 0))
    (error "bad modulus specified for MOD type specifier: ~
             ~/sb-impl:print-type-specifier/"
           n))
  `(integer 0 ,(1- n)))

(sb-xc:deftype signed-byte (&optional s)
  (cond ((eq s '*) 'integer)
        ((and (integerp s) (> s 0))
         (let ((bound (ash 1 (1- s))))
           `(integer ,(- bound) ,(1- bound))))
        (t
         (error "bad size specified for SIGNED-BYTE type specifier: ~
                  ~/sb-impl:print-type-specifier/"
                s))))

(sb-xc:deftype unsigned-byte (&optional s)
  (cond ((eq s '*) '(integer 0))
        ((and (integerp s) (> s 0))
         `(integer 0 ,(1- (ash 1 s))))
        (t
         (error "bad size specified for UNSIGNED-BYTE type specifier: ~
                  ~/sb-impl:print-type-specifier/"
                s))))

;;; ANSI got UNSIGNED-BYTE wrong, prohibiting (UNSIGNED-BYTE 0).
;;; Since this is actually a substantial impediment to clarity...
(sb-xc:deftype unsigned-byte* (&optional s)
  (cond
    ((eq s '*) '(integer 0))
    ((zerop s) '(integer 0 0))
    (t `(unsigned-byte ,s))))

(sb-xc:deftype bit () '(integer 0 1))

(sb-xc:deftype atom () '(not cons))

(sb-xc:deftype base-char ()
  `(character-set ((0 . ,(1- base-char-code-limit)))))

(sb-xc:deftype extended-char ()
  "Type of CHARACTERs that aren't BASE-CHARs."
  '(and character (not base-char)))

(sb-xc:deftype standard-char ()
  "Type corresponding to the characters required by the standard."
  '(member
    #\Newline #\Space #\! #\" #\# #\$ #\% #\& #\' #\( #\) #\* #\+ #\,
    #\- #\. #\/ #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\: #\; #\< #\=
    #\> #\? #\@ #\A #\B #\C #\D #\E #\F #\G #\H #\I #\J #\K #\L #\M
    #\N #\O #\P #\Q #\R #\S #\T #\U #\V #\W #\X #\Y #\Z #\[ #\\ #\]
    #\^ #\_ #\` #\a #\b #\c #\d #\e #\f #\g #\h #\i #\j #\k #\l #\m
    #\n #\o #\p #\q #\r #\s #\t #\u #\v #\w #\x #\y #\z #\{
    #\| #\} #\~))

(sb-xc:deftype keyword ()
  ;; Defining this as (AND SYMBOL ..) lets (SUBTYPEP 'KEYWORD 'SYMBOL)=>T,T.
  '(and symbol (satisfies keywordp)))

(sb-xc:deftype eql (n) `(member ,n))

(sb-xc:deftype vector (&optional element-type size)
  `(array ,element-type (,size)))

(sb-xc:deftype simple-vector (&optional size)
  `(simple-array t (,size)))

(sb-xc:deftype base-string (&optional size)
  `(array base-char (,size)))
(sb-xc:deftype simple-base-string (&optional size)
  `(simple-array base-char (,size)))
(sb-xc:deftype string (&optional size)
  `(or (array character (,size))
       (array nil (,size))
       (base-string ,size)))
(sb-xc:deftype simple-string (&optional size)
  `(or (simple-array character (,size))
       (simple-array nil (,size))
       (simple-base-string ,size)))
;;; On Unicode builds, SIMPLE-CHARACTER-STRING is a builtin type.
;;; For non-Unicode it is convenient to be able to use the type name
;;; as an alias of SIMPLE-BASE-STRING.
#-sb-unicode
(sb-xc:deftype simple-character-string (&optional size)
  `(simple-base-string ,size))

(sb-xc:deftype bit-vector (&optional size)
  `(array bit (,size)))

(sb-xc:deftype simple-bit-vector (&optional size)
  `(simple-array bit (,size)))

(sb-xc:deftype compiled-function ()
  '(and function #+(or sb-eval sb-fasteval) (not interpreted-function)))

;;; Stub type in case there are no interpreted functions
#-(or sb-eval sb-fasteval) (sb-xc:deftype interpreted-function () nil)

(sb-xc:deftype simple-fun () '(satisfies simple-fun-p))

(sb-xc:deftype closure () '(satisfies closurep))

;;;; some private types that we use in defining the standard functions,
;;;; or implementing declarations in standard compiler transforms

;;; semistandard types
(sb-xc:deftype generalized-boolean () t)

(sb-xc:deftype format-control ()
  '(or string function))

(sb-xc:deftype condition-designator-head ()
  '(or format-control symbol condition sb-pcl::condition-class))

(sb-xc:deftype restart-designator ()
  '(or (and symbol (not null)) restart))

;; FIXME: this fails to consider an EQL-SPECIALIZER a TYPE-SPECIFIER.
;; SPECIFIER-TYPE has the explicit-check declaration, so that kinda works,
;; because it doesn't check against this specifier.
;; Somewhat miraculously, SB-C::CANONIZED-DECL-SPEC also works, so this works:
;;  (lambda (x) (declare (#.(sb-mop::intern-eql-specializer 'serial) x)) x)
;; But I suspect this must be reverted to (OR LIST SYMBOL INSTANCE)
;; or we have to hack EQL-SPECIALIZER into 'condition-boot', sad as that is.
(sb-xc:deftype type-specifier ()
  '(or list symbol classoid class))

;;; array rank, total size...
(sb-xc:deftype array-rank () `(integer 0 (,sb-xc:array-rank-limit)))
(sb-xc:deftype array-total-size ()
  `(integer 0 (,sb-xc:array-total-size-limit)))

;;; The range returned by SXHASH and PSXHASH
(sb-xc:deftype hash () `(integer 0 ,sb-xc:most-positive-fixnum))

;;; something legal in an evaluated context
;;; FIXME: could probably go away
(sb-xc:deftype form () t)

(sb-xc:deftype string-designator () '(or string symbol character))

;;; a thing legal in places where we want the name of a file
(sb-xc:deftype filename () '(or string pathname))

;;; legal args to pathname functions
(sb-xc:deftype pathname-designator ()
  '(or string pathname synonym-stream file-stream))
(sb-xc:deftype logical-host-designator ()
  '(or host string))
(sb-xc:deftype pathname-component-case ()
  '(member :local :common))

(sb-xc:deftype package-designator () '(or string-designator package))
;;; a designator for a list of symbols
(sb-xc:deftype symbols-designator () '(or list symbol))

;;; a thing returned by the irrational functions. We assume that they
;;; never compute a rational result.
(sb-xc:deftype irrational ()
  '(or float (complex float)))

;;; character components
(sb-xc:deftype char-code () `(integer 0 (,sb-xc:char-code-limit)))

;;; a consed sequence result. If a vector, is a simple array.
(sb-xc:deftype consed-sequence ()
  '(or (simple-array * (*)) list extended-sequence))

;;; the :END arg to a sequence
(sb-xc:deftype sequence-end () '(or null index))

;;; the :COUNT arg to a sequence
(sb-xc:deftype sequence-count ()
  `(or null integer))

;;; a valid argument to a stream function
(sb-xc:deftype stream-designator () '(or stream (member nil t)))

;;; something valid as the :EXTERNAL-FORMAT argument to OPEN, LOAD,
;;; COMPILE-FILE and friends.
(sb-xc:deftype external-format-designator ()
  '(or keyword (cons keyword)))

;;; a thing that can be passed to FUNCALL & friends
;;;
;;; FIXME: should be FUNCTION-DESIGNATOR?
(sb-xc:deftype callable () '(or function symbol))

;;; decomposing floats into integers
(sb-xc:deftype single-float-exponent ()
  `(integer ,(- sb-vm:single-float-normal-exponent-min
                sb-vm:single-float-bias
                sb-vm:single-float-digits)
            ,(- sb-vm:single-float-normal-exponent-max
                sb-vm:single-float-bias)))
(sb-xc:deftype double-float-exponent ()
  `(integer ,(- sb-vm:double-float-normal-exponent-min
                sb-vm:double-float-bias
                sb-vm:double-float-digits)
            ,(- sb-vm:double-float-normal-exponent-max
                sb-vm:double-float-bias)))
(sb-xc:deftype single-float-int-exponent ()
  `(integer ,(- sb-vm:single-float-normal-exponent-min
                sb-vm:single-float-bias
                (* sb-vm:single-float-digits 2))
            ,(- sb-vm:single-float-normal-exponent-max
                sb-vm:single-float-bias
                sb-vm:single-float-digits)))
(sb-xc:deftype double-float-int-exponent ()
  `(integer ,(- sb-vm:double-float-normal-exponent-min sb-vm:double-float-bias
                (* sb-vm:double-float-digits 2))
            ,(- sb-vm:double-float-normal-exponent-max sb-vm:double-float-bias
                sb-vm:double-float-digits)))
(sb-xc:deftype single-float-significand ()
  `(integer 0 (,(ash 1 sb-vm:single-float-digits))))
(sb-xc:deftype double-float-significand ()
  `(integer 0 (,(ash 1 sb-vm:double-float-digits))))

;;; Common logic for %%TYPEP and CROSS-TYPEP
(defmacro number-typep (object type)
  `(let ((object ,object) (type ,type))
     (and (numberp object)
          (let ((num (if (complexp object) (realpart object) object)))
            (ecase (numeric-type-class type)
              (integer (and (integerp num)
                            ;; If the type is (COMPLEX INTEGER), it can
                            ;; only match the object if both real and imag
                            ;; parts are integers.
                            (or (not (complexp object))
                                (integerp (imagpart object)))))
              (rational (rationalp num))
              (float
               (ecase (numeric-type-format type)
                 ;; (short-float (typep num 'short-float))
                 (single-float (typep num 'single-float))
                 (double-float (typep num 'double-float))
                 ;; (long-float (typep num 'long-float))
                 ((nil) (floatp num))))
              ((nil) t)))
          (flet ((bound-test (val)
                   (let ((low (numeric-type-low type))
                         (high (numeric-type-high type)))
                     (and (cond ((null low) t)
                                ((listp low) (sb-xc:> val (car low)))
                                (t (sb-xc:>= val low)))
                          (cond ((null high) t)
                                ((listp high) (sb-xc:< val (car high)))
                                (t (sb-xc:<= val high)))))))
            (ecase (numeric-type-complexp type)
              ((nil) t)
              (:complex
               (and (complexp object)
                    (bound-test (realpart object))
                    (bound-test (imagpart object))))
              (:real
               (and (not (complexp object))
                    (bound-test object))))))))

(declaim (inline character-in-charset-p))
(defun character-in-charset-p (char set &aux (code (sb-xc:char-code char)))
  (dolist (pair (character-set-type-pairs set) nil)
    (destructuring-bind (low . high) pair
      (when (<= low code high)
        (return t)))))

(/show0 "deftypes-for-target.lisp end of file")
