/*
  BUFFER C — Excitable Medium / Wave Activity Field
 
  This buffer implements a Hodgepodge machine-inspired excitable medium,
  producing travelling waves of activation across cortical territories.
  It models the principle of Hebbian plasticity — neurons that fire
  together wire together — and introduces the oscillatory, spiral, and
  fungal-sync dynamics observed in biological neural tissue.
 
  Each pixel stores a single excitation state value [0.0, 1.0].
  Pixels cycle through three discrete phases:
 
    QUIESCENT [state < 0.1] — resting. Can be ignited if the average
    excitation of same-population neighbours exceeds threshold 0.08.
    Only same-population neighbours contribute — waves do not cross
    territory borders, giving each population independent wave dynamics.
 
    EXCITED [state > 0.6] — firing. Transitions toward refractory by
    decrementing state by 0.08 per frame.
 
    REFRACTORY [0.1 < state < 0.6] — recovering. Cannot be re-excited.
    Decrements by 0.04 per frame back toward quiescent.
 
  Rare spontaneous ignition (probability ~0.0001 per pixel per frame)
  seeds new wave fronts, preventing waves from dying out entirely.
 
  Two additional mechanisms:
 
    POST-LESION HYPEREXCITABILITY — pixels in the low-damage range
    (recently recolonized) receive a 0.35 activity boost, modelling
    post-stroke cortical hyperexcitability observed clinically. Healed
    lesion sites pulse brighter than surrounding tissue temporarily.
 
    DAMAGE SUPPRESSION — excitability scales with (1 - damage), so
    heavily damaged pixels go silent and do not propagate waves.
 
  Wave activity feeds back into Buffer A, biasing recolonization in
  favour of more active populations — coherent territories that sustain
  wave propagation expand more aggressively into vacant territory.
 
  Reads from: iChannel0 (Buffer A), iChannel1 (self)
 */


float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    // random init to seed wave dynamics
    if (iFrame == 0) {
        fragColor = vec4(hash(uv * 13.7) * 0.15, 0.0, 0.0, 1.0);
        return;
    }

    // read territory from buffer A
    vec4 territory = texture(iChannel0, uv);
    float myPop = territory.r;
    float myDamage = territory.g;

    // dead pixels dont fire
    if (myPop == 0.0 || myDamage > 0.9) {
        fragColor = vec4(0.0);
        return;
    }

    float state = texture(iChannel1, uv).r;

    // sample 8 neighbours — only count same population
    // waves dont cross territory borders
    float sumSame = 0.0;
    float countSame = 0.0;

    vec2 dirs[8];
    dirs[0] = vec2( texel.x,  0.0);
    dirs[1] = vec2(-texel.x,  0.0);
    dirs[2] = vec2( 0.0,      texel.y);
    dirs[3] = vec2( 0.0,     -texel.y);
    dirs[4] = vec2( texel.x,  texel.y);
    dirs[5] = vec2(-texel.x,  texel.y);
    dirs[6] = vec2( texel.x, -texel.y);
    dirs[7] = vec2(-texel.x, -texel.y);

    for (int i = 0; i < 8; i++) {
        vec4 nb = texture(iChannel0, uv + dirs[i]);
        float nbState = texture(iChannel1, uv + dirs[i]).r;
        // only same population neighbours count toward ignition
        if (abs(nb.r - myPop) < 0.1 && nb.g < 0.5) {
            sumSame += nbState;
            countSame += 1.0;
        }
    }

    float avgSame = countSame > 0.0 ? sumSame / countSame : 0.0;
    float newState = 0.0;

    // hodgepodge excitable medium state machine
    if (state < 0.1) {
        // quiescent — ignite if enough excited same-pop neighbours
        if (avgSame > 0.08) {
            newState = min(1.0, avgSame * 2.2 + hash(uv + fract(iTime * 0.3)) * 0.05);
        }
    } else if (state > 0.6) {
        // excited — transition toward refractory
        newState = state - 0.08;
    } else {
        // refractory — cool back down to quiescent
        newState = state - 0.04;
    }

    // rare spontaneous ignition — keeps waves alive
    if (hash(uv + fract(iTime * 0.7)) > 0.9999) {
        newState = 1.0;
    }

    // damage suppresses excitability
    newState *= (1.0 - myDamage * 0.95);

    // recently healed pixels are hyperactive — they sit in the low-damage
    // range and boost their own firing above baseline
    // this models post-stroke cortical hyperexcitability
    float recentlyHealed = smoothstep(0.0, 0.25, myDamage)
                         * (1.0 - smoothstep(0.25, 0.45, myDamage))
                         * step(0.5, myPop);
    newState = min(1.0, newState + recentlyHealed * 0.35);

    fragColor = vec4(clamp(newState, 0.0, 1.0));
}
