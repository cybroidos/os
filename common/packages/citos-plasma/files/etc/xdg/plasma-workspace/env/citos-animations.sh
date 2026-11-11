# CIT-OS: keep KWin's animations (windows opening, closing, minimising) on
# machines without a graphics card. KWin turns them off by itself when it
# draws in software (llvmpipe), which is every VM; they cost little there.
export KWIN_EFFECTS_FORCE_ANIMATIONS=1
