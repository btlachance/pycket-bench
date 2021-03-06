#lang racket/base
(require "time-run.rktl")
(provide generate) ;for gen-inputs
;; The Computer Language Benchmarks Game
;; http://shootout.alioth.debian.org/
;;
;; fasta - benchmark
;;
;; Very loosely based on the Chicken variant by Anthony Borla, some
;; optimizations taken from the GCC version by Petr Prokhorenkov, and
;; additional heavy optimizations by Eli Barzilay (not really related to
;; the above two now).
;;
;; If you use some of these optimizations in other solutions, please
;; include a proper attribution to this Racket code.

(define +alu+
  (bytes-append #"GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
                #"GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
                #"CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
                #"ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
                #"GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
                #"AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
                #"AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"))

(define IUB
  '([#\a 0.27] [#\c 0.12] [#\g 0.12] [#\t 0.27] [#\B 0.02]
    [#\D 0.02] [#\H 0.02] [#\K 0.02] [#\M 0.02] [#\N 0.02]
    [#\R 0.02] [#\S 0.02] [#\V 0.02] [#\W 0.02] [#\Y 0.02]))

(define HOMOSAPIEN
  '([#\a 0.3029549426680] [#\c 0.1979883004921]
    [#\g 0.1975473066391] [#\t 0.3015094502008]))

(define line-length 60)

;; ----------------------------------------

(require racket/require (for-syntax racket/base))

;; ----------------------------------------

(define (repeat-fasta header N sequence)
  (define out (current-output-port))
  (define len (bytes-length sequence))
  (define buf (make-bytes (+ len line-length)))
  (bytes-copy! buf 0 sequence)
  (bytes-copy! buf len sequence 0 line-length)
  (display header out)
  (let loop ([n N] [start 0])
    (when (> n 0)
      (let ([end (+ start (min n line-length))])
        (write-bytes buf out start end)
        (newline)
        (loop (- n line-length) (if (> end len) (- end len) end))))))

;; ----------------------------------------

(define IA 3877)
(define IC 29573)
(define IM 139968)
(define IM.0 (exact->inexact IM))

(define-syntax-rule (define/IM (name id) E)
  (begin (define V
           (let ([v (make-vector IM)])
             (for ([id (in-range IM)]) (vector-set! v id E))
             v))
         (define-syntax-rule (name id) (vector-ref V id))))

(define/IM (random-next cur) (modulo (+ IC (* cur IA)) IM))

(define (make-lookup-table frequency-table)
  (define v (make-bytes IM))
  (let loop ([t frequency-table] [c 0] [c. 0.0])
    (unless (null? t)
      (let* ([c1. (+ c. (* IM.0 (cadar t)))]
             [c1 (inexact->exact (ceiling c1.))]
             [b (char->integer (caar t))])
        (for ([i (in-range c c1)]) (bytes-set! v i b))
        (loop (cdr t) c1 c1.))))
  v)

(define (random-fasta header N table R)
  (define out (current-output-port))
  (define lookup-byte (make-lookup-table table))
  (define (n-randoms to R)
    (let loop ([n 0] [R R])
      (if (< n to)
        (let ([R (random-next R)])
          (bytes-set! buf n (bytes-ref lookup-byte R))
          (loop (+ n 1) R))
        (begin (write-bytes buf out 0 (+ to 1)) R))))
  (define (make-line! buf start R)
    (let ([end (+ start line-length)])
      (bytes-set! buf end LF)
      (let loop ([n start] [R R])
        (if (< n end)
          (let ([R (random-next R)])
            (bytes-set! buf n (bytes-ref lookup-byte R))
            (loop (+ n 1) R))
          R))))
  (define LF (char->integer #\newline))
  (define buf (make-bytes (+ line-length 1)))
  (define-values (full-lines last) (quotient/remainder N line-length))
  (define C
    (let* ([len+1 (+ line-length 1)]
           [buflen (* len+1 IM)]
           [buf (make-bytes buflen)])
      (let loop ([R R] [i 0])
        (if (< i buflen)
          (loop (make-line! buf i R) (+ i len+1))
          buf))))
  (bytes-set! buf line-length LF)
  (display header out)
  (let loop ([i full-lines] [R R])
    (if (> i IM)
      (begin (display C out) (loop (- i IM) R))
      (let loop ([i i] [R R])
        (cond [(> i 0) (loop (- i 1) (n-randoms line-length R))]
              [(> last 0) (bytes-set! buf last LF) (n-randoms last R)]
              [else R])))))

;; ----------------------------------------

(define (generate n)
  (repeat-fasta ">ONE Homo sapiens alu\n" (* n 2) +alu+)
  (random-fasta ">THREE Homo sapiens frequency\n" (* n 5) HOMOSAPIEN
                (random-fasta ">TWO IUB ambiguity codes\n" (* n 3) IUB 42))
  (void))

(time-run generate)
