//
//  WearableDashboardDemo.swift
//  Papercut
//
//  Standalone demo replicating the wearable dashboard animations.
//  Frame-accurate recreation based on video analysis.
//

import SwiftUI

// MARK: - Main Demo View
struct WearableDashboardDemo: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int = 0
    @State private var showOnboarding = true
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showOnboarding {
                DemoOnboardingView(showOnboarding: $showOnboarding)
                    .transition(.opacity)
            } else {
                DemoDashboardView(
                    currentPage: $currentPage,
                    dragOffset: $dragOffset,
                    isDragging: $isDragging
                )
                .transition(.opacity)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.6), value: showOnboarding)
    }
}

// MARK: - Onboarding View
struct DemoOnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var revealProgress: [Bool] = Array(repeating: false, count: 5)
    @State private var blobPhase: CGFloat = 0

    let lines = [
        "Gather all the",
        "analytics in one",
        "place from my",
        "wearable",
        "devices"
    ]

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.78, blue: 0.35),
                    Color(red: 0.88, green: 0.72, blue: 0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // White glow blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.95), .white.opacity(0.5), .white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: 30 + sin(blobPhase) * 10, y: -50 + cos(blobPhase) * 15)

            // Purple blob
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.7, green: 0.3, blue: 0.8).opacity(0.9),
                            Color(red: 0.6, green: 0.2, blue: 0.7).opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 320, height: 200)
                .blur(radius: 70)
                .offset(x: -20, y: 280)

            // Text reveal
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<lines.count, id: \.self) { index in
                    Text(lines[index])
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(revealProgress[index] ? 1 : 0)
                        .offset(y: revealProgress[index] ? 0 : 25)
                        .blur(radius: revealProgress[index] ? 0 : 8)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.12),
                            value: revealProgress[index]
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 24)
            .padding(.top, 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                blobPhase = .pi * 2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                for i in 0..<lines.count {
                    revealProgress[i] = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation { showOnboarding = false }
            }
        }
        .onTapGesture {
            withAnimation { showOnboarding = false }
        }
    }
}

// MARK: - Dashboard View
struct DemoDashboardView: View {
    @Binding var currentPage: Int
    @Binding var dragOffset: CGFloat
    @Binding var isDragging: Bool

    @State private var appeared = false

    let screenWidth = UIScreen.main.bounds.width

    // Transition progress: 0 = no drag, 1 = full page
    var transitionProgress: CGFloat {
        min(abs(dragOffset) / (screenWidth * 0.5), 1.0)
    }

    var body: some View {
        ZStack {
            DemoDottedGrid().ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(currentPage == 0 ? "Watch" : "Ring")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isDragging ? 1 - transitionProgress : 1)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 16)

                // Cards container
                GeometryReader { geo in
                    ZStack {
                        // Watch page
                        WatchPageView(
                            appeared: appeared && currentPage == 0,
                            transitionProgress: currentPage == 0 ? transitionProgress : 1 - transitionProgress,
                            isCurrentPage: currentPage == 0,
                            isDragging: isDragging
                        )
                        .offset(x: watchPageOffset)
                        .opacity(watchPageOpacity)

                        // Ring page
                        RingPageView(
                            appeared: appeared && currentPage == 1,
                            transitionProgress: currentPage == 1 ? transitionProgress : 1 - transitionProgress,
                            isCurrentPage: currentPage == 1,
                            isDragging: isDragging
                        )
                        .offset(x: ringPageOffset)
                        .opacity(ringPageOpacity)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 60
                                let velocity = value.predictedEndTranslation.width - value.translation.width

                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isDragging = false
                                    if value.translation.width < -threshold || velocity < -300 {
                                        if currentPage < 1 { currentPage = 1 }
                                    } else if value.translation.width > threshold || velocity > 300 {
                                        if currentPage > 0 { currentPage = 0 }
                                    }
                                    dragOffset = 0
                                }
                            }
                    )
                }

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.white : Color.white.opacity(0.3))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.3), value: currentPage)
                .padding(.bottom, 16)

                DemoBottomToolbar()
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Page Offsets & Opacity

    private var watchPageOffset: CGFloat {
        if currentPage == 0 {
            return isDragging ? dragOffset * 0.7 : 0
        } else {
            return isDragging ? -screenWidth * 0.6 + dragOffset * 0.7 : -screenWidth
        }
    }

    private var ringPageOffset: CGFloat {
        if currentPage == 1 {
            return isDragging ? dragOffset * 0.7 : 0
        } else {
            return isDragging ? screenWidth * 0.6 + dragOffset * 0.7 : screenWidth
        }
    }

    private var watchPageOpacity: Double {
        if currentPage == 0 {
            return isDragging ? Double(1 - transitionProgress * 0.5) : 1
        } else {
            return isDragging ? Double(transitionProgress * 0.8) : 0
        }
    }

    private var ringPageOpacity: Double {
        if currentPage == 1 {
            return isDragging ? Double(1 - transitionProgress * 0.5) : 1
        } else {
            return isDragging ? Double(transitionProgress * 0.8) : 0
        }
    }
}

// MARK: - Watch Page
struct WatchPageView: View {
    let appeared: Bool
    let transitionProgress: CGFloat
    let isCurrentPage: Bool
    let isDragging: Bool

    // During drag: collapse to single column
    var columns: [GridItem] {
        if isDragging && transitionProgress > 0.2 {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 10) {
                // Balance - Mesh gradient (green center, coral edges)
                MeshGradientCard(
                    centerColor: Color(red: 0.2, green: 0.5, blue: 0.3),
                    edgeColor: Color(red: 0.9, green: 0.55, blue: 0.5),
                    delay: 0.0,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress
                ) {
                    CardContent(
                        title: "Balance", subtitle: "Vitamin D",
                        value: "85", bottomText: "Good",
                        showWaveform: true
                    )
                }

                // Sleep - Teal gradient
                MeshGradientCard(
                    centerColor: Color(red: 0.3, green: 0.6, blue: 0.65),
                    edgeColor: Color(red: 0.2, green: 0.5, blue: 0.55),
                    delay: 0.05,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress
                ) {
                    CardContent(
                        title: "Sleep", subtitle: "Quality",
                        value: "25", valueSuffix: "%", bottomText: "Vitamin D",
                        showCircularProgress: true
                    )
                }

                // Enhance Mood - Pink/magenta
                MeshGradientCard(
                    centerColor: Color(red: 0.85, green: 0.4, blue: 0.55),
                    edgeColor: Color(red: 0.7, green: 0.25, blue: 0.45),
                    delay: 0.1,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress
                ) {
                    CardContent(
                        title: "Enhance", subtitle: "Mood",
                        value: "+12", bottomText: "Nice",
                        showBarChart: true
                    )
                }

                // Skin Damage - Deep blue
                MeshGradientCard(
                    centerColor: Color(red: 0.15, green: 0.25, blue: 0.55),
                    edgeColor: Color(red: 0.1, green: 0.18, blue: 0.4),
                    delay: 0.15,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress
                ) {
                    CardContent(
                        title: "Skin Damage", subtitle: "Monitoring",
                        showScatterPlot: true
                    )
                }

                // Red Light - Red to purple
                MeshGradientCard(
                    centerColor: Color(red: 0.85, green: 0.35, blue: 0.3),
                    edgeColor: Color(red: 0.4, green: 0.25, blue: 0.5),
                    delay: 0.2,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress,
                    height: 90
                ) {
                    SmallCardContent(title: "Red Light", subtitle: "Monitoring", showGradientBar: true)
                }

                // Productivity - Orange to purple
                MeshGradientCard(
                    centerColor: Color(red: 0.95, green: 0.55, blue: 0.35),
                    edgeColor: Color(red: 0.45, green: 0.3, blue: 0.55),
                    delay: 0.25,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress,
                    height: 90
                ) {
                    SmallCardContent(title: "Increases", subtitle: "Productivity", showDots: true)
                }
            }
            .padding(.horizontal, 14)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDragging)
    }
}

// MARK: - Ring Page
struct RingPageView: View {
    let appeared: Bool
    let transitionProgress: CGFloat
    let isCurrentPage: Bool
    let isDragging: Bool

    var columns: [GridItem] {
        if isDragging && transitionProgress > 0.2 {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 10) {
                // Today's Metrix - Rainbow radial (blue center → orange → red edge)
                RainbowMeshCard(
                    delay: 0.0,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress
                ) {
                    CardContent(
                        title: "Today's", subtitle: "Metrix",
                        value: "2.0", bottomText: "All Day lite",
                        showTickMarks: true
                    )
                }

                // Natural vs Artificial - Yellow/lime
                MeshGradientCard(
                    centerColor: Color(red: 0.7, green: 0.75, blue: 0.3),
                    edgeColor: Color(red: 0.55, green: 0.6, blue: 0.2),
                    delay: 0.05,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress
                ) {
                    CardContent(
                        title: "Natural vs", subtitle: "Artificial",
                        value: "75", valueSuffix: "%", bottomText: "Vitamin D",
                        showSlider: true
                    )
                }

                // Light Variability - Brown/tan radial
                MeshGradientCard(
                    centerColor: Color(red: 0.5, green: 0.35, blue: 0.3),
                    edgeColor: Color(red: 0.7, green: 0.55, blue: 0.45),
                    delay: 0.1,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress
                ) {
                    CardContent(
                        title: "Light Variability", subtitle: nil,
                        value: "75", valueSuffix: "lx", bottomText: "Norma",
                        showDottedCircle: true
                    )
                }

                // Color Experience - Dark teal
                MeshGradientCard(
                    centerColor: Color(red: 0.25, green: 0.42, blue: 0.42),
                    edgeColor: Color(red: 0.18, green: 0.35, blue: 0.35),
                    delay: 0.15,
                    appeared: appeared,
                    isDragging: isDragging,
                    transitionProgress: transitionProgress
                ) {
                    CardContent(
                        title: "Color", subtitle: "Experience",
                        bottomText: "Green",
                        showGlowCircle: true, showSpectrum: true
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDragging)
    }
}

// MARK: - Mesh Gradient Card
struct MeshGradientCard<Content: View>: View {
    let centerColor: Color
    let edgeColor: Color
    let delay: Double
    let appeared: Bool
    let isDragging: Bool
    let transitionProgress: CGFloat
    var height: CGFloat = 160
    @ViewBuilder let content: () -> Content

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    // Hide content during transition
    var showContent: Bool {
        !isDragging || transitionProgress < 0.3
    }

    var body: some View {
        ZStack {
            // Mesh-style gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(edgeColor)
                .overlay(
                    RadialGradient(
                        colors: [centerColor, centerColor.opacity(0.8), edgeColor.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

            if showContent {
                content()
                    .padding(14)
            }
        }
        .frame(height: height)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            if appeared {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
        .onChange(of: appeared) { _, val in
            if val {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Rainbow Mesh Card (for Today's Metrix)
struct RainbowMeshCard<Content: View>: View {
    let delay: Double
    let appeared: Bool
    let isDragging: Bool
    let transitionProgress: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var showContent: Bool {
        !isDragging || transitionProgress < 0.3
    }

    var body: some View {
        ZStack {
            // Multi-ring radial gradient (heat map style)
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.85, green: 0.45, blue: 0.35))
                .overlay(
                    ZStack {
                        // Outer orange ring
                        RadialGradient(
                            colors: [
                                Color(red: 0.95, green: 0.6, blue: 0.4).opacity(0),
                                Color(red: 0.95, green: 0.6, blue: 0.4),
                                Color(red: 0.85, green: 0.45, blue: 0.35)
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 140
                        )
                        // Green ring
                        RadialGradient(
                            colors: [
                                Color(red: 0.4, green: 0.7, blue: 0.5).opacity(0),
                                Color(red: 0.5, green: 0.75, blue: 0.55),
                                Color(red: 0.5, green: 0.75, blue: 0.55).opacity(0)
                            ],
                            center: .center,
                            startRadius: 35,
                            endRadius: 70
                        )
                        // Blue center
                        RadialGradient(
                            colors: [
                                Color(red: 0.3, green: 0.5, blue: 0.8),
                                Color(red: 0.35, green: 0.55, blue: 0.75),
                                Color(red: 0.35, green: 0.55, blue: 0.75).opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

            if showContent {
                content()
                    .padding(14)
            }
        }
        .frame(height: 160)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            if appeared {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
        .onChange(of: appeared) { _, val in
            if val {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(delay)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

// MARK: - Card Content
struct CardContent: View {
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var valueSuffix: String? = nil
    var bottomText: String? = nil
    var showWaveform: Bool = false
    var showCircularProgress: Bool = false
    var showBarChart: Bool = false
    var showScatterPlot: Bool = false
    var showTickMarks: Bool = false
    var showSlider: Bool = false
    var showDottedCircle: Bool = false
    var showGlowCircle: Bool = false
    var showSpectrum: Bool = false

    @State private var animatedValue: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            // Header
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .opacity(0.7)
                }
            }

            Spacer()

            // Value display
            if let val = value {
                if showDottedCircle {
                    DemoDottedGauge(value: Int(animatedValue))
                } else if showCircularProgress {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 65, height: 65)
                        DemoArcProgress()
                        HStack(alignment: .top, spacing: 1) {
                            Text("\(Int(animatedValue))")
                                .font(.system(size: 28, weight: .light, design: .rounded))
                            if let suffix = valueSuffix {
                                Text(suffix).font(.system(size: 12)).offset(y: 4)
                            }
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: 1) {
                        Text(value == "2.0" ? String(format: "%.1f", animatedValue) : "\(Int(animatedValue))")
                            .font(.system(size: 40, weight: .light, design: .rounded))
                            .contentTransition(.numericText())
                        if let suffix = valueSuffix {
                            Text(suffix).font(.system(size: 14)).offset(y: 6)
                        }
                    }
                }
            }

            // Visualizations
            if showWaveform { DemoWaveform().frame(height: 22) }
            if showBarChart { DemoBarChart().frame(height: 26) }
            if showScatterPlot { DemoScatterPlot().frame(height: 55) }
            if showTickMarks { DemoTickMarks().frame(height: 18) }
            if showSlider { DemoSlider().frame(height: 16) }
            if showGlowCircle { DemoGlowCircle().frame(height: 45) }
            if showSpectrum { DemoSpectrum().frame(height: 20) }

            Spacer()

            // Bottom text
            if let bottom = bottomText {
                Text(bottom)
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
        }
        .foregroundColor(.white)
        .onAppear {
            let target: Double = {
                guard let v = value else { return 0 }
                if v == "2.0" { return 2.0 }
                return Double(v.replacingOccurrences(of: "+", with: "")) ?? 0
            }()
            withAnimation(.spring(response: 0.9, dampingFraction: 0.6).delay(0.4)) {
                animatedValue = target
            }
        }
    }
}

// MARK: - Small Card Content
struct SmallCardContent: View {
    let title: String
    let subtitle: String
    var showGradientBar: Bool = false
    var showDots: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(subtitle).font(.system(size: 11)).opacity(0.7)
            Spacer()
            if showGradientBar { DemoGradientBar() }
            if showDots { DemoDotRow() }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Visualization Components

struct DemoDottedGrid: View {
    var body: some View {
        Canvas { ctx, size in
            for x in stride(from: 0, to: size.width, by: 18) {
                for y in stride(from: 0, to: size.height, by: 18) {
                    ctx.fill(Circle().path(in: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.12)))
                }
            }
        }
        .background(Color.black)
    }
}

struct DemoBottomToolbar: View {
    var body: some View {
        HStack {
            Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5).frame(width: 48, height: 48)
                .overlay(Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.8)))
            Spacer()
            Text("Edite").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.12)))
            Spacer()
            Circle().fill(Color.white).frame(width: 48, height: 48)
                .overlay(Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)).foregroundColor(.black))
        }
        .padding(.horizontal, 28)
    }
}

struct DemoWaveform: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width, h = geo.size.height, mid = h / 2
                path.move(to: CGPoint(x: 0, y: mid))
                for x in stride(from: 0, to: w, by: 2) {
                    let p = x / w
                    let y = mid + sin(p * .pi * 3.5 + phase) * sin(p * .pi) * (h * 0.35)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.yellow, lineWidth: 2)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { phase = .pi * 2 }
        }
    }
}

struct DemoArcProgress: View {
    @State private var progress: CGFloat = 0
    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(LinearGradient(colors: [.green, .yellow], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 70, height: 70)
            .rotationEffect(.degrees(-90))
            .onAppear {
                withAnimation(.easeOut(duration: 1).delay(0.4)) { progress = 0.7 }
            }
    }
}

struct DemoBarChart: View {
    @State private var heights: [CGFloat] = Array(repeating: 5, count: 8)
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.65)).frame(width: 4, height: heights[i])
            }
        }
        .onAppear {
            for i in 0..<8 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4 + Double(i) * 0.05)) {
                    heights[i] = CGFloat.random(in: 12...26)
                }
            }
        }
    }
}

struct DemoScatterPlot: View {
    @State private var show = false
    let pts: [(CGFloat, CGFloat, CGFloat)] = [(0.2,0.4,6),(0.3,0.55,10),(0.4,0.45,5),(0.5,0.6,8),(0.55,0.5,12),(0.6,0.65,7),(0.7,0.52,9),(0.8,0.58,14),(0.9,0.48,6)]
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width/2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width/2, y: geo.size.height))
                    p.move(to: CGPoint(x: 0, y: geo.size.height/2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height/2))
                }.stroke(Color.white.opacity(0.15), lineWidth: 1)
                ForEach(0..<pts.count, id: \.self) { i in
                    Circle().fill(Color.cyan).frame(width: pts[i].2, height: pts[i].2)
                        .position(x: pts[i].0 * geo.size.width, y: pts[i].1 * geo.size.height)
                        .opacity(show ? 1 : 0).scaleEffect(show ? 1 : 0)
                        .animation(.spring(response: 0.4).delay(0.45 + Double(i) * 0.04), value: show)
                }
            }
        }
        .onAppear { show = true }
    }
}

struct DemoTickMarks: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { i in
                RoundedRectangle(cornerRadius: 0.5).fill(Color.white.opacity(i == 10 ? 1 : 0.3)).frame(width: 1.5, height: i == 10 ? 14 : 7)
            }
        }
    }
}

struct DemoSlider: View {
    @State private var pos: CGFloat = 20
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.white.opacity(0.25)).frame(height: 1.5)
            Triangle().fill(Color.white).frame(width: 10, height: 7).offset(x: pos)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8).delay(0.5)) { pos = 80 }
        }
    }
}

struct DemoDottedGauge: View {
    let value: Int
    @State private var active: Int = 0
    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { i in
                Circle().fill(Color.yellow.opacity(i < active ? 0.85 : 0.2)).frame(width: 4, height: 4).offset(y: -30).rotationEffect(.degrees(Double(i) * 15))
            }
            VStack(spacing: 0) {
                Text("\(value)").font(.system(size: 24, weight: .light, design: .rounded))
                Text("lx").font(.system(size: 11))
            }
        }
        .onAppear {
            for i in 1...18 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.03) {
                    withAnimation(.spring(response: 0.25)) { active = i }
                }
            }
        }
    }
}

struct DemoGlowCircle: View {
    @State private var glow = false
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.25), lineWidth: 1).frame(width: 40, height: 40)
            Circle().fill(RadialGradient(colors: [.green, .green.opacity(0)], center: .center, startRadius: 0, endRadius: 16)).frame(width: 26, height: 26).opacity(glow ? 1 : 0.4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

struct DemoSpectrum: View {
    @State private var offset: CGFloat = -20
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 1) { ForEach(0..<26, id: \.self) { _ in Rectangle().fill(Color.white.opacity(0.35)).frame(width: 2, height: 10) } }
            Triangle().fill(Color.white).frame(width: 8, height: 5).offset(x: offset)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7).delay(0.5)) { offset = 0 }
        }
    }
}

struct DemoGradientBar: View {
    @State private var pos: CGFloat = 0
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing)).frame(height: 6)
            Triangle().fill(Color.yellow).frame(width: 10, height: 8).offset(x: pos, y: -10)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7).delay(0.5)) { pos = 90 }
        }
    }
}

struct DemoDotRow: View {
    @State private var count = 0
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<9, id: \.self) { i in
                Circle().fill(Color.white.opacity(i < count ? 0.9 : 0.25)).frame(width: 7, height: 7)
            }
        }
        .onAppear {
            for i in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.08) {
                    withAnimation(.spring(response: 0.3)) { count = i }
                }
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    WearableDashboardDemo()
}
