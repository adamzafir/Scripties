import SwiftUI

struct Settings: View {
    enum ColourScheme: String, CaseIterable, Identifiable {
        case light
        case dark
        case system

        var id: String { rawValue }
        var title: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "Default"
            }
        }
    }

   
    @AppStorage("appColorScheme") private var storedFlavorRawValue: String = ColourScheme.system.rawValue

    
    private var storedColourScheme: ColourScheme {
        get { ColourScheme(rawValue: storedFlavorRawValue) ?? .system }
        set { storedFlavorRawValue = newValue.rawValue }
    }
    
    
    
    
    
    
    
    

   
    private var colourSchemeBinding: Binding<ColourScheme> {
        Binding(
            get: { ColourScheme(rawValue: storedFlavorRawValue) ?? .system },
            set: { storedFlavorRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Appearance", selection: colourSchemeBinding) {
                    ForEach(ColourScheme.allCases) { scheme in
                        Text(scheme.title).tag(scheme)
                    }
                }

            }
            .preferredColorScheme(storedColourScheme.colorScheme)
            .navigationTitle("Settings")
        }
    }
}

extension Settings.ColourScheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

#Preview {
    Settings()
}
