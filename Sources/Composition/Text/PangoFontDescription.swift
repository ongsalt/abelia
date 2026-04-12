import CPango

// i should generate this from gir

public class PangoFontDescription {
    public let desc: OpaquePointer

    public init() {
        desc = pango_font_description_new()
    }

    public init(_ fontDescription: String) {
        desc = pango_font_description_from_string(fontDescription)
    }

    public init(family: String, size: Int) {
        desc = pango_font_description_from_string("\(family) \(size)")
    }

    deinit {
        pango_font_description_free(desc)
    }

    public var family: String? {
        get {
            pango_font_description_get_family(desc).map { String(cString: $0) }
        }
        set {
            pango_font_description_set_family(desc, newValue)
        }
    }

    public func setFamilyStatic(_ family: UnsafePointer<CChar>?) {
        pango_font_description_set_family_static(desc, family)
    }

    public var style: PangoStyle {
        get {
            pango_font_description_get_style(desc)
        }
        set {
            pango_font_description_set_style(desc, newValue)
        }
    }

    public var variant: PangoVariant {
        get {
            pango_font_description_get_variant(desc)
        }
        set {
            pango_font_description_set_variant(desc, newValue)
        }
    }

    public var weight: PangoWeight {
        get {
            pango_font_description_get_weight(desc)
        }
        set {
            pango_font_description_set_weight(desc, newValue)
        }
    }

    public var stretch: PangoStretch {
        get {
            pango_font_description_get_stretch(desc)
        }
        set {
            pango_font_description_set_stretch(desc, newValue)
        }
    }

    public var size: Int32 {
        get {
            pango_font_description_get_size(desc)
        }
        set {
            pango_font_description_set_size(desc, newValue)
        }
    }

    public var absoluteSize: Double {
        get {
            Double(pango_font_description_get_size(desc)) / Double(PANGO_SCALE)
        }
        set {
            pango_font_description_set_absolute_size(desc, newValue)
        }
    }

    public var sizeIsAbsolute: Bool {
        pango_font_description_get_size_is_absolute(desc) != 0
    }

    public var gravity: PangoGravity {
        get {
            pango_font_description_get_gravity(desc)
        }
        set {
            pango_font_description_set_gravity(desc, newValue)
        }
    }

    public var variations: String? {
        get {
            pango_font_description_get_variations(desc).map { String(cString: $0) }
        }
        set {
            pango_font_description_set_variations(desc, newValue)
        }
    }

    public func setVariationsStatic(_ variations: UnsafePointer<CChar>?) {
        pango_font_description_set_variations_static(desc, variations)
    }

    public var features: String? {
        get {
            pango_font_description_get_features(desc).map { String(cString: $0) }
        }
        set {
            pango_font_description_set_features(desc, newValue)
        }
    }

    public func setFeaturesStatic(_ features: UnsafePointer<CChar>?) {
        pango_font_description_set_features_static(desc, features)
    }

    public var color: PangoFontColor {
        get {
            pango_font_description_get_color(desc)
        }
        set {
            pango_font_description_set_color(desc, newValue)
        }
    }
}
