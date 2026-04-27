/*
  BUFFER B — Chemical Signalling Field
 
  This buffer simulates the diffusing chemoattractant field that guides
  which population expands into damaged territory. It is the primary
  mechanism distinguishing perilesional from vicarious remapping.
 
  Each pixel stores four concentration values — one per population:
    red   = population 1 signal concentration
    green = population 2 signal concentration
    blue  = population 3 signal concentration
    alpha = population 4 signal concentration
 
  Each frame, two processes run:
 
    1. DIFFUSION — a standard discrete Laplacian (5-point stencil) spreads
       all four concentrations simultaneously across the canvas. A decay
       factor of 0.98 per frame prevents unbounded accumulation. This is
       mathematically equivalent to the diffusion term in Turing (1952)
       reaction-diffusion systems, applied independently to four species.
 
    2. EMISSION — vacant or heavily damaged pixels (read from Buffer A)
       inject a strong signal (0.08) into all four channels simultaneously.
       This is the recovery broadcast — all populations sense the vacancy
       equally. Owned pixels inject a weak self-reinforcing signal (0.02)
       into their own channel only, implementing lateral inhibition —
       established territories resist invasion by suppressing competitor
       signal in their region.
 
  The spatial gradient of this field is what Buffer A uses to decide which
  population wins recolonization. A population physically closer to a
  lesion site has a stronger concentration there, naturally producing
  perilesional recovery under normal conditions.
 
  Reads from: iChannel0 (self), iChannel1 (Buffer A)
 */


void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 texel = 1.0 / iResolution.xy;

    if (iFrame == 0) {
        fragColor = vec4(0.0);
        return;
    }

    // laplacian diffusion across all 4 channels
    vec4 curr = texture(iChannel0, uv);
    vec4 n = texture(iChannel0, uv + vec2(0.0,  texel.y));
    vec4 s = texture(iChannel0, uv - vec2(0.0,  texel.y));
    vec4 e = texture(iChannel0, uv + vec2(texel.x, 0.0));
    vec4 w = texture(iChannel0, uv - vec2(texel.x, 0.0));

    vec4 diffused = curr + 0.2 * ((n + s + e + w) * 0.25 - curr);
    diffused *= 0.98;

    // read territory from buffer A
    vec4 territory = texture(iChannel1, uv);
    float popID = territory.r;
    float damage = territory.g;

    // vacant pixels emit into all channels — the recovery broadcast
    if (popID == 0.0 || damage > 0.7) {
        diffused += vec4(0.08);
    }

    // owned pixels reinforce their own channel — lateral inhibition
    if (popID > 0.0) {
        int idx = int(popID) - 1;
        diffused[idx] += 0.02 * (1.0 - damage);
    }

    // extra emission at mouse lesion site
    if (iMouse.z > 0.0) {
        float d = distance(fragCoord, iMouse.xy);
        if (d < 84.0) {
            diffused += vec4(0.05) * (1.0 - smoothstep(0.0, 84.0, d));
        }
    }

    fragColor = clamp(diffused, 0.0, 1.0);
}
