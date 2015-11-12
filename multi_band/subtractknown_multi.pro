function subtractknown_multi, sig, specDens, sigm, binwidth, bbody=bbody, eq_sigm=eq_sigm, emissivity=emissivity, tdust=tdust, real_pos=real_pos, real_amp=real_amp
compile_opt idl2, HIDDEN
    ; Input
    ;   sig         - struct containing
    ;       signal  - input multi-band map from which we subtract tallest peak
    ;       freqs   - frequencies of bands
    ;   specdens    - list of spectral densities of each band of noise
    ;   sigm        - sigma of profile to be subtracted (correspending to first band)
    ;   binwidth    - binwidth of signal map, in arccminutes
    ;   /bbody      - use bbody instead of R-J power law
    ;   /EQ_SIGM    - 0 [default] - 1/f dependence
    ;               - 1 - all equal
    ;   /emissivity - emissivity of body (default = 1.5)
    ;   real_pos    - known positions of beam (debugging purposes mostly

    ; Output - Struct containing
    ;   xparam      - estimated x-coordinate of peak
    ;   yparam      - estimated y-coordinate of peak
    ;   Aest        - estimated height of peaks in first band
    ;   map         - signal minus peak
    ;   sigm_x0     - theoretical deviation of xparam
    ;   sigm_a      - theoretical deviation of Aest
    ;
    ; subtracts given peak of width sigm from map signal containing noise specdens

freqs = sig.freqs
signal = sig.signal
temp = max(freqs, max_freq); get max frequency

; parameters
range = double(sqrt(n_elements(signal[*,*,0])))
num_bands = n_elements(freqs)
; set up default values
if ~ keyword_set(emissivity) then emissivity = 1.5D else emissivity = double(emissivity)
if ~ keyword_set(tdust) then tdust = 40D else tdust = double(tdust)

; generate amps, sigm
if keyword_set(emissivity) then begin
    if keyword_set(tdust) then begin
        if ~ keyword_set(bbody) then amps = amps_multi(1, freqs, emissivity=emissivity, tdust=tdust) else amps = amps_multi(1, freqs, bbody=bbody, emissivity=emissivity, tdust=tdust) ; whatever we get out of the estimator is just multiplied by amps for return
    endif else begin
        if ~ keyword_set(bbody) then amps = amps_multi(1, freqs, emissivity=emissivity) else amps = amps_multi(1, freqs, bbody=bbody, emissivity=emissivity) ; whatever we get out of the estimator is just multiplied by amps for return
    endelse
endif else begin
    if keyword_set(tdust) then begin
        if ~ keyword_set(bbody) then amps = amps_multi(1, freqs, tdust=tdust) else amps = amps_multi(1, freqs, bbody=bbody, tdust=tdust) ; whatever we get out of the estimator is just multiplied by amps for return
    endif else begin
        if ~ keyword_set(bbody) then amps = amps_multi(1, freqs) else amps = amps_multi(1, freqs, bbody=bbody) ; whatever we get out of the estimator is just multiplied by amps for return
    endelse
endelse
if ~ keyword_set(eq_sigm) then sigms = sigm_multi(sigm, freqs) else sigms = sigm_multi(sigm, freqs, eq_sigm=eq_sigm)

if keyword_set(real_pos) then begin
    xparam = real_pos[0]
    yparam = real_pos[1]
endif

aest = real_amp

; residual/chi2/derivative dbeta
dbeta = 0 ; derivative dbeta
dt_dust = 0 ; derivative dt_dust
chi2 = 0
inv_sigm_T = 0
for i=0, num_bands - 1 do begin
    ; compute residual
    signal[*,*,i] = signal[*,*,i] - addgauss(amps[i] * aest, sigms[i], xparam, yparam, dblarr(range, range))

    ; mask out DC bin
    mask = make_array(range, range, value=1D)
    mask[(range - 1) / 2, (range - 1) / 2] = 0 ; mask out DC bin
    chi2 += (range )^2 * TOTAL(abs(fft_shift(fft(signal[*,*,i])))^2 / (specdens[*,*,i]) * mask)

endfor

return, {sig: {signal:signal, freqs:freqs},$
    chi2:chi2}
    ; uncertainty in pixels, not arcmins
end
