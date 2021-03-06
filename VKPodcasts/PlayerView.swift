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

struct PlayerSwitcher: View {
    @Binding var podcastsStorage: PodcastsStorage
    @Binding var podcast: Podcast
    @Binding var userInfo: UserInfo
    @State var episodeIdx: Int
    
    var body: some View {
        ForEach(podcast.episodes.indices) { i in
            if episodeIdx == i {
                PlayerView(episode: $podcast.episodes[i], podcast: $podcast, podcastsStorage: $podcastsStorage, episodeIdx: $episodeIdx, userInfo: $userInfo)
            }
        }
    }
}

struct PlayerView: View {
    @State var currentSpeedId: Int = 2
    @State var paused: Bool = false
    @State var isBottomSheetOpened = false
    @Binding var episode: Episode
    @Binding var podcast: Podcast
    @Binding var podcastsStorage: PodcastsStorage
    @Binding var episodeIdx: Int
    @Binding var userInfo: UserInfo
    @State var citiesCache: CitiesCache = .init(cities: [])
    @State var reactionsUnlocked = true
    @State var loaded = false
    @State var episodeSwitching = false
    
    func reactionsLock() {
        withAnimation {
            reactionsUnlocked = false
            Timer.scheduledTimer(withTimeInterval: 10, repeats: false, block: { _ in
                withAnimation {
                    reactionsUnlocked = true
                }
            })
        }
    }
    
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
                    if let logo = episode.logoCache {
                        logo
                            .resizable()
                            .frame(width: size.width/1.2, height: 150)
                            .blur(radius: 50)
                            .offset(x: 0, y: -50)
                    }
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
                                    
                                    ReactionsGraph(selfSize: size, duration: durationSeconds, currentTime: $currentSecond, episode: $episode, reactions: podcast.reactions)
                                }
                                CustomSlider(offset: $trackPercentage, hasUpdates: $sliderHasUpdates)
                                    .onChange(of: sliderHasUpdates, perform: { hasUpdates in
                                        if hasUpdates {
                                            let seconds = Double(trackPercentage) * durationSeconds
                                            
                                            player.seek(to: .init(seconds: seconds, preferredTimescale: player.currentTime().timescale))
                                            sliderHasUpdates = false
                                        }
                                    })
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
                                        .foregroundColor(.primary)
                                        .frame(width: 60, height: 25)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color("ControlSecondary"), lineWidth: 3)
                                        )
                                })
                                Spacer()
                                if episodeSwitching {
                                    Button(action: {
                                        episodeIdx += 1
                                    }, label: {
                                        Image(systemName: "backward.fill")
                                            .resizable()
                                            .foregroundColor(.primary)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30)
                                    })
                                        .disabled(episodeIdx == podcast.episodes.count - 1)
                                        .opacity(episodeIdx == podcast.episodes.count - 1 ? 0 : 1)
                                } else {
                                    Button(action: {
                                        let currentTime = player.currentTime()
                                        let seconds = max(0, currentTime.seconds - 15)
                                        let cm = CMTime(seconds: seconds, preferredTimescale: currentTime.timescale)
                                        player.seek(to: cm)
                                    }, label: {
                                        Image(systemName: "gobackward.15")
                                            .resizable()
                                            .foregroundColor(.primary)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30)
                                    })
                                }
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
                                        .foregroundColor(.primary)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 34)
                                })
                                Spacer()
                                if episodeSwitching {
                                    Button(action: {
                                        episodeIdx -= 1
                                    }, label: {
                                        Image(systemName: "forward.fill")
                                            .resizable()
                                            .foregroundColor(.primary)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30)
                                    })
                                        .disabled(episodeIdx == 0)
                                        .opacity(episodeIdx == 0 ? 0 : 1)
                                } else {
                                    Button(action: {
                                        let currentTime = player.currentTime()
                                        let seconds = currentTime.seconds + 15
                                        let cm = CMTime(seconds: seconds, preferredTimescale: currentTime.timescale)
                                        player.seek(to: cm)
                                    }, label: {
                                        Image(systemName: "goforward.15")
                                            .resizable()
                                            .foregroundColor(.primary)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30)
                                    })
                                }
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        episodeSwitching.toggle()
                                    }
                                }, label: {
                                    Image(systemName: "ellipsis")
                                        .resizable()
                                        .foregroundColor(.primary)
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
                    Spacer()
                    if let logo = episode.logoCache {
                        logo
                            .resizable()
                            .frame(width: size.width*0.8, height: reactionItemSize + 30)
                            .cornerRadius(20)
                            .blur(radius: 40)
                    }
                }
                
                let bottomSize = proxy.safeAreaInsets.bottom
                
                BottomSheetView(isOpen: $isBottomSheetOpened, maxHeight: bottomSize + 15 * 4 + reactionItemSize * 5 + 50, bottomSize: bottomSize) {
                    VStack(alignment: .center) {
                        Text("reacts")
                            .font(.title)
                            .bold()
                            .foregroundColor(.primary)
                        if reactionsUnlocked {
                            HStack {
                                Spacer()
                                LazyVGrid(columns: [.init(.adaptive(minimum: isBottomSheetOpened ? reactionItemSize * 1.45 : reactionItemSize * 0.95))], spacing: 20) {
                                    ForEach(podcast.reactions) { reaction in
                                        if reaction.isAvailable {
                                            Button(action: {
                                                withAnimation {
                                                    reactionsLock()
                                                    let stat = Stat(time: Int(currentSecond * 1000), reactionId: reaction.id, sex: userInfo.sex, age: userInfo.age, cityId: userInfo.cityId)
                                                    episode.statistics.append(stat)
                                                    let userStat = UserStat(date: Date())
                                                    statStorage.addStat(userStat)
                                                    podcastsStorage.save()
                                                    episode.recalculate()
                                                }
                                            }, label: {
                                                VStack {
                                                    ReactionItem(width: reactionItemSize, emoji: reaction.emoji)
                                                    if isBottomSheetOpened {
                                                        Text(reaction.description)
                                                            .font(.callout)
                                                            .foregroundColor(.primary)
                                                            .lineLimit(1)
                                                    }
                                                }
                                            }).disabled(!reactionsUnlocked)
                                        }
                                    }
                                }
                                Spacer()
                            }
                                .padding(.horizontal, 15)
                        } else {
                            Text("reacts-limit")
                                .foregroundColor(.init(white: 0.65))
                                .padding(.horizontal, 30)
                        }
                    }
                }.edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear() {
            if !loaded {
                var cityIds = episode.statistics.map { stat in
                    return stat.cityId
                }
                cityIds.append(userInfo.cityId)
                getCities(tIds: cityIds, destination: $citiesCache.cities)
                
                for i in 0..<podcast.reactions.count {
                    podcast.reactions[i].isAvailable = episode.defaultReactions.contains(podcast.reactions[i].id)
                }
                if let url = URL(string: episode.audioUrl) {
                    player = AVPlayer(url: url)
                    player.seek(to: .init(seconds: statStorage.seconds(episode.id), preferredTimescale: .init(10)))
                    play()
                }
                paused = false
                loaded = true
            }
            playerTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { _ in
                self.checkTime()
            })
            secondsTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true, block: { _ in
                statStorage.setSeconds(id: episode.id, seconds: currentSecond)
            })
        }
        .onDisappear() {
            playerTimer?.invalidate()
            secondsTimer?.invalidate()
            player.pause()
            paused = true
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: StatView(reactions: podcast.reactions, episode: episode, citiesCache: citiesCache)) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(5)
                        .frame(height: 30)
                }
            }
        }
        .navigationTitle("")
    }
    
    @State var player = AVPlayer()
    @State var playerTimer: Timer?
    @State var currentTime = "0:00"
    @State var timeLeft: String = ""
    @State var trackPercentage: CGFloat = 0
    @State var sliderHasUpdates = false
    
    @State var currentSecond: Double = 0
    @State var durationSeconds: Double = 0
    @State var secondsTimer: Timer?
    
    func turnReactions(container: TimedReactionsContainer, isAvailable: Bool) {
        for reaction in container.availableReactions {
            for i in 0..<podcast.reactions.count {
                if reaction == podcast.reactions[i].id {
                    podcast.reactions[i].isAvailable = isAvailable
                }
            }
        }
    }
    
    func checkTime() {
        currentSecond = player.currentTime().seconds
        for timedContainer in episode.timedReactions {
            turnReactions(container: timedContainer, isAvailable: (timedContainer.from...timedContainer.to).contains(Int(currentSecond)))
        }
        currentTime = secondsToString(seconds: Int(currentSecond))
        if let duration = player.currentItem?.duration.seconds, !duration.isNaN {
            durationSeconds = duration
            let secondsLeft = duration - currentSecond
            if paused {
                timeLeft = episode.duration
            } else {
                timeLeft = "-" + secondsToString(seconds: Int(secondsLeft))
            }
            if !sliderHasUpdates {
                trackPercentage = CGFloat(currentSecond / duration)
            }
        }
    }
    
    func play() {
        player.playImmediately(atRate: Float(speeds[currentSpeedId]))
    }
    
    func pause() {
        player.pause()
        checkTime()
    }
}

struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView(episode: .constant(.init()), podcast: .constant(.init()), podcastsStorage: .constant(.init()), episodeIdx: .constant(0), userInfo: .constant(UserInfo()))
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
