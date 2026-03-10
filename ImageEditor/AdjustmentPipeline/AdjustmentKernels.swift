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
        color *= exp2(exposureEV);

        float Y = max(dot(color, vec3(0.2126, 0.7152, 0.0722)), 0.00001);
        float t = clamp(Y / (1.0 + Y), 0.0, 0.9995);

        float pivot = 0.18 / 1.18;
        float epsilon = 0.0001;
        float logitValue = log((t + epsilon) / (1.0 - t + epsilon));
        float logitPivot = log((pivot + epsilon) / (1.0 - pivot + epsilon));
        float contrastGain = exp2(contrast * 0.85);
        t = 1.0 / (1.0 + exp(-(logitPivot + (logitValue - logitPivot) * contrastGain)));

        float shadowWeight = 1.0 - smoothstep(0.05, 0.25, t);
        shadowWeight *= shadowWeight;
        float shadowExponent = exp2(-shadows * 1.35);
        float shadowTarget = pow(clamp(t, 0.0, 1.0), shadowExponent);
        t = mix(t, shadowTarget, clamp(abs(shadows) * shadowWeight, 0.0, 1.0));

        float highlightWeight = smoothstep(0.20, 0.50, t);
        highlightWeight *= highlightWeight;
        float highlightExponent = exp2(highlights * 1.35);
        float highlightTarget = 1.0 - pow(max(1.0 - t, 0.00001), highlightExponent);
        t = mix(t, highlightTarget, clamp(abs(highlights) * highlightWeight, 0.0, 1.0));

        float blackWeight = 1.0 - smoothstep(0.02, 0.12, t);
        blackWeight *= blackWeight;
        float blackExponent = exp2(-blacks * 1.65);
        float blackTarget = pow(clamp(t, 0.0, 1.0), blackExponent);
        t = mix(t, blackTarget, clamp(abs(blacks) * blackWeight, 0.0, 1.0));

        // Whites shape the bright endpoint energy with a stronger soft-knee
        // response than highlights, so the control remains visible on normal
        // images instead of only affecting the last few clipped bins.
        float whiteWeight = smoothstep(0.18, 0.44, t);
        whiteWeight *= 0.45 + 0.55 * whiteWeight;
        float whiteAmount = whites * whiteWeight;
        float positiveWhiteTarget = t + whiteAmount * (0.24 + 0.76 * t) * (1.0 - t);
        float negativeWhiteTarget = t + whiteAmount * t * (0.42 + 0.58 * whiteWeight);
        float whiteTarget = whites >= 0.0 ? positiveWhiteTarget : negativeWhiteTarget;
        t = mix(t, clamp(whiteTarget, 0.0, 0.9995), clamp(abs(whiteAmount) * 1.35, 0.0, 1.0));

        t = clamp(t, 0.0, 0.9995);
        float remappedY = t / max(1.0 - t, 0.0005);
        float scale = remappedY / Y;
        return vec4(max(color * scale, 0.0), pixel.a);
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
