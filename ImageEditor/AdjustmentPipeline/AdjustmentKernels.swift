@preconcurrency import CoreImage
import Foundation

enum AdjustmentKernels {
    static let baseTone = CIColorKernel(source: """
    kernel vec4 baseTone(__sample pixel,
                         float exposureEV,
                         float contrast,
                         float highlights,
                         float shadows,
                         float whites,
                         float blacks) {
        vec3 color = max(pixel.rgb, vec3(0.0));
        // Keep the exposure slider photographic in character, but calm down
        // the user-facing response so the editor does not jump too far on
        // small moves.
        color *= exp2(exposureEV * 0.6);

        if (highlights < 0.0) {
            float highlightAmount = -highlights;
            float peak = max(color.r, max(color.g, color.b));
            float peakT = peak / (1.0 + peak);
            float peakWeight = smoothstep(0.22, 0.84, peakT);
            float shoulder = mix(1.45, 0.32, highlightAmount);
            float headroom = max(peak - shoulder, 0.0);
            float compression = 2.0 + highlightAmount * 22.0;
            float compressedPeak = shoulder + log(1.0 + headroom * compression) / compression;
            float peakScale = compressedPeak / max(peak, 0.00001);
            color = mix(color, color * peakScale, clamp(highlightAmount * peakWeight * 1.28, 0.0, 1.0));
        }

        float Y = max(dot(color, vec3(0.2126, 0.7152, 0.0722)), 0.00001);
        float t = clamp(Y / (1.0 + Y), 0.0, 0.9995);

        float pivot = 0.18 / 1.18;
        float epsilon = 0.0001;
        float logitValue = log((t + epsilon) / (1.0 - t + epsilon));
        float logitPivot = log((pivot + epsilon) / (1.0 - pivot + epsilon));
        float contrastGain = exp2(contrast * 0.85);
        t = 1.0 / (1.0 + exp(-(logitPivot + (logitValue - logitPivot) * contrastGain)));
        float tonalT = t;

        float shadowWeight = 1.0 - smoothstep(0.03, 0.38, tonalT);
        shadowWeight *= 0.45 + 0.55 * shadowWeight;
        if (shadows >= 0.0) {
            float shadowAmount = shadows;
            float shadowGain = exp2(shadowAmount * shadowWeight * 1.05);
            float liftedY = Y * shadowGain;
            float shadowTarget = clamp(liftedY / (1.0 + liftedY), 0.0, 0.9995);
            t = mix(t, shadowTarget, clamp(shadowAmount * shadowWeight * 0.92, 0.0, 1.0));
        } else {
            float shadowAmount = -shadows;
            float shadowExponent = exp2(shadowAmount * 0.75);
            float shadowTarget = pow(clamp(t, 0.0, 1.0), shadowExponent);
            t = mix(t, shadowTarget, clamp(shadowAmount * shadowWeight * 0.82, 0.0, 1.0));
        }

        float highlightWeight = smoothstep(0.16, 0.82, tonalT);
        highlightWeight *= 0.32 + 0.68 * highlightWeight;
        if (highlights < 0.0) {
            float highlightAmount = -highlights;
            float highlightExponent = exp2(-highlightAmount * 1.10);
            float highlightTarget = 1.0 - pow(max(1.0 - t, 0.00001), highlightExponent);
            t = mix(t, highlightTarget, clamp(highlightAmount * highlightWeight * 1.08, 0.0, 1.0));
        } else if (highlights > 0.0) {
            float highlightExponent = exp2(highlights * 0.86);
            float highlightTarget = 1.0 - pow(max(1.0 - t, 0.00001), highlightExponent);
            t = mix(t, highlightTarget, clamp(highlights * highlightWeight * 0.94, 0.0, 1.0));
        }

        // Blacks should anchor the toe, but still reach a little farther into
        // the low mids than a pure endpoint control.
        float blackWeight = 1.0 - smoothstep(0.02, 0.16, t);
        blackWeight *= blackWeight;
        float blackExponent = exp2(-blacks * 1.55);
        float blackTarget = pow(clamp(t, 0.0, 1.0), blackExponent);
        t = mix(t, blackTarget, clamp(abs(blacks) * blackWeight, 0.0, 1.0));

        // Whites should brighten a broad upper range, but still keep a soft
        // shoulder so bright bark/cloud detail is not flattened immediately.
        float whiteWeight = smoothstep(0.08, 0.52, t);
        whiteWeight *= 0.44 + 0.56 * whiteWeight;
        float whiteExponent = exp2(whites * 0.72);
        float whiteTarget = 1.0 - pow(max(1.0 - t, 0.00001), whiteExponent);
        t = mix(t, clamp(whiteTarget, 0.0, 0.9995), clamp(abs(whites) * whiteWeight * 1.04, 0.0, 1.0));

        t = clamp(t, 0.0, 0.9995);
        float remappedY = t / max(1.0 - t, 0.0005);
        float scale = remappedY / Y;
        color = max(color * scale, 0.0);

        float shoulderProtect = clamp(max(-highlights, 0.0) + max(whites, 0.0) * 0.22, 0.0, 1.0);
        if (shoulderProtect > 0.0) {
            float peak = max(color.r, max(color.g, color.b));
            float peakT = peak / (1.0 + peak);
            float protectWeight = smoothstep(0.26, 0.86, peakT);
            float shoulder = mix(1.30, 0.42, shoulderProtect);
            float headroom = max(peak - shoulder, 0.0);
            float compression = 2.0 + shoulderProtect * 18.0;
            float compressedPeak = shoulder + log(1.0 + headroom * compression) / compression;
            float protectScale = compressedPeak / max(peak, 0.00001);
            color = mix(color, color * protectScale, clamp(protectWeight * (0.70 + shoulderProtect * 0.30), 0.0, 1.0));
        }

        return vec4(color, pixel.a);
    }
    """)

    static let blend = CIColorKernel(source: """
    kernel vec4 blend(__sample original, __sample processed, float amount) {
        return vec4(mix(original.rgb, processed.rgb, amount), processed.a);
    }
    """)

    static let sceneCompress = CIColorKernel(source: """
    kernel vec4 sceneCompress(__sample pixel) {
        vec3 color = max(pixel.rgb, vec3(0.0));
        return vec4(color / (1.0 + color), pixel.a);
    }
    """)

    static let sceneExpand = CIColorKernel(source: """
    kernel vec4 sceneExpand(__sample pixel) {
        vec3 color = clamp(pixel.rgb, 0.0, 0.9995);
        return vec4(color / max(1.0 - color, vec3(0.0005)), pixel.a);
    }
    """)

    static let highlightColorProtect = CIColorKernel(source: """
    kernel vec4 highlightColorProtect(__sample pixel, float amount) {
        vec3 color = max(pixel.rgb, vec3(0.0));
        float Y = max(dot(color, vec3(0.2126, 0.7152, 0.0722)), 0.0001);
        float peak = max(color.r, max(color.g, color.b));
        float tonal = peak / (1.0 + peak);

        vec3 neutral = vec3(Y);
        float relativeChroma = length(color - neutral) / max(Y + 0.05, 0.05);

        float brightMask = smoothstep(0.42, 0.88, tonal);
        float chromaMask = smoothstep(0.08, 0.62, relativeChroma);
        float protect = clamp(amount, 0.0, 1.0) * brightMask * chromaMask;

        // Only pull the most aggressive recovered highlights back toward
        // neutral. This suppresses blue/purple color casts without washing out
        // normal highlight color everywhere else.
        vec3 corrected = mix(color, neutral, protect * 0.34);
        return vec4(corrected, pixel.a);
    }
    """)

    static let domainRemap = CIColorKernel(source: """
    kernel vec4 domainRemap(__sample pixel, vec3 domainMin, vec3 domainMax) {
        vec3 mapped = clamp((pixel.rgb - domainMin) / max(domainMax - domainMin, vec3(0.0001)), 0.0, 1.0);
        return vec4(mapped, pixel.a);
    }
    """)

    static let clarity = CIColorKernel(source: """
    kernel vec4 clarity(__sample original, __sample blurred, float amount) {
        float originalLuma = max(dot(original.rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0001);
        float blurredLuma = dot(blurred.rgb, vec3(0.2126, 0.7152, 0.0722));
        float detail = originalLuma - blurredLuma;
        float softDetail = detail / (1.0 + abs(detail) * 12.0);
        float tonal = originalLuma / (1.0 + originalLuma);
        float midtoneMask = smoothstep(0.08, 0.32, tonal) * (1.0 - smoothstep(0.72, 0.96, tonal));
        float targetLuma = max(0.0, originalLuma + softDetail * amount * midtoneMask * 1.45);
        float scale = targetLuma / originalLuma;
        return vec4(max(original.rgb * scale, 0.0), original.a);
    }
    """)

    static let sharpen = CIColorKernel(source: """
    kernel vec4 sharpen(__sample original, __sample blurred, float amount, float threshold) {
        float originalLuma = max(dot(original.rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0001);
        float blurredLuma = dot(blurred.rgb, vec3(0.2126, 0.7152, 0.0722));
        float detail = originalLuma - blurredLuma;
        float edgeMask = smoothstep(threshold, threshold * 4.0, abs(detail));
        float protectedDetail = detail / (1.0 + abs(detail) * 18.0);
        float targetLuma = max(0.0, originalLuma + protectedDetail * amount * edgeMask * 1.15);
        float scale = targetLuma / originalLuma;
        return vec4(max(original.rgb * scale, 0.0), original.a);
    }
    """)

    static let grain = CIColorKernel(source: """
    kernel vec4 grain(__sample pixel, __sample noiseA, __sample noiseB, float amount) {
        float n1 = dot(noiseA.rgb, vec3(0.3333)) - 0.5;
        float n2 = dot(noiseB.rgb, vec3(0.3333)) - 0.5;
        float grain = (n1 * 0.72) + (n2 * 0.28);
        float luma = max(dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722)), 0.0);
        float tonal = luma / (1.0 + luma);
        float highlightFade = 1.0 - smoothstep(0.68, 0.98, tonal);
        float strength = mix(0.35, 1.0, highlightFade);
        float applied = grain * amount * strength * 0.12;
        return vec4(max(pixel.rgb + vec3(applied), 0.0), pixel.a);
    }
    """)
}
