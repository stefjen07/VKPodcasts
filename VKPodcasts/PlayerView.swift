//
//  PlayerView.swift
//  PlayerView
//
//  Created by Евгений on 11.08.2021.
//

import SwiftUI
import AVFoundation
import MediaPlayer

var speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5]

func createGradient(opacities: [Double]) -> LinearGradient {
    var colors = [Color]()
    for i in opacities {
        colors.append(Color("Background").opacity(i))
    }
    return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct BottomSheetView<Content: View>: View {
    @Binding var isOpen: Bool
    
    let radius: CGFloat = 30
    let snapRatio: CGFloat = 0.5
    
    let indicatorWidth: CGFloat = 65
    let indicatorHeight: CGFloat = 5

    let maxHeight: CGFloat
    let minHeight: CGFloat
    let content: Content
    
    private var offset: CGFloat {
        isOpen ? 0 : maxHeight - minHeight
    }

    private var indicator: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.secondary)
            .frame(
                width: indicatorWidth,
                height: indicatorHeight)
    }

    @GestureState private var translation: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                self.indicator
                    .padding(15)
                    .preferredColorScheme(.dark)
                self.content
            }
            .frame(width: geometry.size.width, height: self.maxHeight, alignment: .top)
            .background(Blur(effect: UIBlurEffect(style: .dark)))
            .cornerRadius(radius, corners: [.topLeft, .topRight])
            .frame(height: geometry.size.height, alignment: .bottom)
            .shadow(color: .white, radius: 2)
            .offset(y: max(self.offset + self.translation, 0))
            .animation(.interactiveSpring(), value: isOpen)
            .animation(.interactiveSpring(), value: translation)
            .gesture(
                DragGesture().updating(self.$translation) { value, state, _ in
                    state = value.translation.height
                }.onEnded { value in
                    let snapDistance = self.maxHeight * snapRatio
                    guard abs(value.translation.height) > snapDistance else {
                        return
                    }
                    self.isOpen = value.translation.height < 0
                }
            )
        }
    }

    init(isOpen: Binding<Bool>, maxHeight: CGFloat, bottomSize: CGFloat, @ViewBuilder content: () -> Content) {
        self.minHeight = 160 + bottomSize
        self.maxHeight = maxHeight
        self.content = content()
        self._isOpen = isOpen
    }
}

class CustomSlider: UISlider {
    @IBInspectable var trackHeight: CGFloat = 3
    @IBInspectable var thumbRadius: CGFloat = 20

    private lazy var thumbView: UIView = {
        let thumb = UIView()
        thumb.backgroundColor = UIColor(named: "VKColor")
        return thumb
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        let thumb = thumbImage(radius: thumbRadius)
        setThumbImage(thumb, for: .normal)
    }

    private func thumbImage(radius: CGFloat) -> UIImage {
        thumbView.frame = CGRect(x: 0, y: radius / 2, width: radius, height: radius)
        thumbView.layer.cornerRadius = radius / 2

        let renderer = UIGraphicsImageRenderer(bounds: thumbView.bounds)
        return renderer.image { rendererContext in
            thumbView.layer.render(in: rendererContext.cgContext)
        }
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var newRect = super.trackRect(forBounds: bounds)
        newRect.size.height = trackHeight
        return newRect
    }

}

struct SliderRepresentable: UIViewRepresentable {
    @Binding var value: Float
    
    func updateUIView(_ uiView: CustomSlider, context: Context) {
        
    }
    
    func makeUIView(context: Context) -> CustomSlider {
        let slider = CustomSlider()
        slider.observe(\.value, changeHandler: { slider, _ in
            self.value = slider.value
        })
        slider.thumbRadius = 15
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.awakeFromNib()
        slider.minimumTrackTintColor = .init(named: "VKColor")
        slider.maximumTrackTintColor = .init(Color("VKColor").opacity(0.2))
        return slider
    }
}

struct Blur: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

let fadeGradient = createGradient(opacities: [0,0.3,0.5,0.675,0.8,0.9,0.95,1])

struct VolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.tintColor = UIColor(Color("ControlSecondary"))
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

struct PlayerView: View {
    @State var currentSpeedId: Int
    @State var paused: Bool
    @State var isBottomSheetOpened = false
    @ObservedObject var episode: Episode
    @Binding var podcast: Podcast
    @Environment(\.presentationMode) var presentation: Binding<PresentationMode>
    
    func changeSpeed() {
        if(currentSpeedId == speeds.count-1) {
            currentSpeedId = 0
        } else {
            currentSpeedId += 1
        }
        player.rate = Float(speeds[currentSpeedId])
        if paused {
            player.pause()
        }
    }
    
    func secondsToString(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        var result = ""
        if hours > 0 {
            result += "\(hours):"
            if minutes < 10 {
                result += "0"
            }
        }
        result += "\(minutes):"
        if seconds < 10 {
            result += "0"
        }
        result += "\(seconds)"
        return result
    }
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let iconSize = size.height * 0.15
            let reactionItemSize = size.width / 6
            
            ZStack {
                Color("Background")
                    .edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    Ellipse()
                        .fill(Color("PodcastSample"))
                        .frame(width: size.width/1.2, height: 150)
                        .blur(radius: 40)
                        .offset(x: 0, y: -50)
                    Spacer()
                }
                VStack(spacing: 0) {
                    fadeGradient
                        .frame(width: size.width, height: size.width/1.7)
                    Color("Background")
                }
                GeometryReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            if let logo = episode.logoCache {
                                logo
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: iconSize, height: iconSize)
                                    .cornerRadius(iconSize * 0.12)
                                    .shadow(radius: 10)
                                    .padding(.top, 20)
                                    .padding(.bottom, 20)
                            } else {
                                Color.gray.opacity(0.3)
                                    .frame(width: iconSize, height: iconSize)
                                    .cornerRadius(iconSize * 0.12)
                                    .shadow(radius: 10)
                                    .padding(.top, 20)
                                    .padding(.bottom, 20)
                            }
                            Text(episode.title)
                                .font(.title)
                                .bold()
                                .lineLimit(1)
                                .foregroundColor(.init("TitlePrimary"))
                                .padding(.horizontal, 5)
                            Text(podcast.author)
                                .foregroundColor(.init("VKColor"))
                                .font(.title3)
                                .bold()
                                .padding(.vertical, 10)
                            Spacer()
                            VStack {
                                GeometryReader { proxy in
                                    let size = proxy.size
                                    
                                    EmojiGraph(selfSize: size)
                                }
                                .frame(height: 20)
                                GeometryReader { proxy in
                                    let size = proxy.size
                                    
                                    ReactionsGraph(selfSize: size)
                                }
                                SliderRepresentable(value: $trackPercentage)
                                HStack {
                                    Text(currentTime)
                                    Spacer()
                                    Text(timeLeft)
                                }.foregroundColor(.init("SecondaryText"))
                            }
                            .padding(10)
                            .padding(.horizontal, 10)
                            .background(Color("SecondaryBackground"))
                            .cornerRadius(10)
                            Spacer(minLength: 25)
                            HStack {
                                Button(action: {
                                    changeSpeed()
                                }, label: {
                                    Text(speeds[currentSpeedId].removeZerosFromEnd() + "x")
                                        .font(.callout)
                                        .bold()
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 25)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color("ControlSecondary"), lineWidth: 3)
                                        )
                                })
                                Spacer()
                                Button(action: {
                                    let currentTime = player.currentTime()
                                    let seconds = max(0, currentTime.seconds - 15)
                                    let cm = CMTime(seconds: seconds, preferredTimescale: currentTime.timescale)
                                    player.seek(to: cm)
                                }, label: {
                                    Image(systemName: "gobackward.15")
                                        .resizable()
                                        .foregroundColor(.white)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30)
                                })
                                Spacer()
                                Button(action: {
                                    paused.toggle()
                                    if paused {
                                        pause()
                                    } else {
                                        play()
                                    }
                                }, label: {
                                    Image(systemName: paused ? "play.fill" : "pause.fill")
                                        .resizable()
                                        .foregroundColor(.white)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 34)
                                })
                                Spacer()
                                Button(action: {
                                    let currentTime = player.currentTime()
                                    let seconds = currentTime.seconds + 15
                                    let cm = CMTime(seconds: seconds, preferredTimescale: currentTime.timescale)
                                    player.seek(to: cm)
                                }, label: {
                                    Image(systemName: "goforward.15")
                                        .resizable()
                                        .foregroundColor(.white)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30)
                                })
                                Spacer()
                                Button(action: {
                                    
                                }, label: {
                                    Image(systemName: "ellipsis")
                                        .resizable()
                                        .foregroundColor(.white)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20)
                                })
                            }
                            Spacer(minLength: 20)
                            HStack {
                                VStack {
                                    Image(systemName: "speaker.fill")
                                        .foregroundColor(Color("ControlSecondary"))
                                    Spacer()
                                }
                                VolumeView()
                                VStack {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundColor(Color("ControlSecondary"))
                                    Spacer()
                                }
                            }
                            .frame(height: 25)
                            .padding(.horizontal, 10)
                            Spacer()
                                .frame(height: 15 * 6 + reactionItemSize + 20)
                        }
                        .padding(.horizontal, 15)
                        .frame(height: scrollProxy.size.height)
                    }
                }
                VStack {
                    HStack {
                        Button(action: {
                            presentation.wrappedValue.dismiss()
                        }, label: {
                            Image(systemName: "chevron.backward")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(5)
                                .frame(height: 30)
                        })
                        Spacer()
                        Button(action: {
                            
                        }, label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(5)
                                .frame(height: 30)
                        })
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.top, 5)
                    Spacer()
                    Ellipse()
                        .fill(Color("PodcastSample"))
                        .frame(width: size.width/1.2, height: size.width/2.4)
                        .blur(radius: 20)
                        .offset(x: 0, y: size.width/12)
                }
                
                let bottomSize = proxy.safeAreaInsets.bottom
                
                BottomSheetView(isOpen: $isBottomSheetOpened, maxHeight: bottomSize + 15 * 4 + reactionItemSize * 5 + 50, bottomSize: bottomSize) {
                    VStack(alignment: .center) {
                        Text("Реакции")
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                        HStack {
                            Spacer()
                            LazyVGrid(columns: [.init(.adaptive(minimum: isBottomSheetOpened ? reactionItemSize * 1.45 : reactionItemSize * 0.95))], spacing: 20) {
                                ForEach(podcast.reactions) { reaction in
                                    Button(action: {
                                        
                                    }, label: {
                                        VStack {
                                            ReactionItem(width: reactionItemSize, emoji: reaction.emoji)
                                            if isBottomSheetOpened {
                                                Text(reaction.description)
                                                    .font(.callout)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                            }
                                        }
                                    })
                                }
                            }
                            Spacer()
                        }.padding(.horizontal, 15)
                    }.gesture(
                        DragGesture(coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.width > .zero
                                    && value.translation.height > -30
                                    && value.translation.height < 30 {
                                    presentation.wrappedValue.dismiss()
                                }
                            }
                    )
                }.edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear() {
            playerTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { timer in
                self.checkTime()
            })
            if let url = URL(string: episode.audioUrl) {
                player = AVPlayer(url: url)
                play()
            }
        }
        .onDisappear() {
            playerTimer?.invalidate()
        }
        .navigationBarHidden(true)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width > .zero
                        && value.translation.height > -30
                        && value.translation.height < 30 {
                        presentation.wrappedValue.dismiss()
                    }
                }
        )
    }
    
    @State var player = AVPlayer()
    @State var playerTimer: Timer?
    @State var currentTime = "0:00"
    @State var timeLeft: String
    @State var trackPercentage: Float = 0
    
    func checkTime() {
        let seconds = player.currentTime().seconds
        currentTime = secondsToString(seconds: Int(seconds))
        if let duration = player.currentItem?.duration.seconds, !duration.isNaN {
            let secondsLeft = duration - seconds
            if paused {
                timeLeft = episode.duration
            } else {
                timeLeft = "-" + secondsToString(seconds: Int(secondsLeft))
            }
            trackPercentage = Float(seconds / duration)
        }
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
        checkTime()
    }
    
    init(episode: Episode, podcast: Binding<Podcast>) {
        _currentSpeedId = .init(initialValue: 2)
        _paused = .init(initialValue: false)
        self.episode = episode
        self._podcast = podcast
        self._timeLeft = .init(initialValue: episode.duration)
    }
}

struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView(episode: .init(), podcast: .constant(.init()))
    }
}

extension Double {
    func removeZerosFromEnd() -> String {
        let formatter = NumberFormatter()
        let number = NSNumber(value: self)
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return String(formatter.string(from: number) ?? "\(self)")
    }
}
