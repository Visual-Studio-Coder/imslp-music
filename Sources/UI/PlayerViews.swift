import SwiftUI
import AVKit

struct PlayerBar:View {
    @Environment(MusicStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    var body:some View {
        HStack(spacing:16) {
            Button { if store.current != nil { store.showPlayer = true } } label: {
                HStack(spacing:12) {
                    CoverArt(title:store.current?.work.composer ?? "Music",url:store.current?.artworkURL,compact:true).frame(width:44,height:44)
                    VStack(alignment:.leading,spacing:3) { Text(store.current?.title ?? "Not Playing").font(.subheadline.weight(.medium)).lineLimit(1); Text(store.current?.work.composer ?? "IMSLP Music").font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    Spacer(minLength:0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("open-player")
            #if os(macOS)
            Button { store.previous() } label: { Image(systemName:"backward.fill") }.buttonStyle(.plain).accessibilityLabel("Previous Track")
            #endif
            PlaybackButton(size:22)
            Button { store.next() } label: { Image(systemName:"forward.fill").font(.title3) }.buttonStyle(.plain).accessibilityLabel("Next Track")
            #if os(macOS)
            Divider().frame(height:28)
            VolumeSlider().frame(width:120)
            Button { openWindow(id:"mini-player") } label: { Image(systemName:"macwindow") }.buttonStyle(.plain).help("Open Mini Player").accessibilityLabel("Open Mini Player")
            #endif
            Button { store.showQueue.toggle() } label: { Image(systemName:"list.bullet").font(.title3) }.buttonStyle(.plain).accessibilityLabel("Playing Next").accessibilityIdentifier("open-queue")
        }.padding(.horizontal,20).padding(.vertical,12).background(.regularMaterial)
            .overlay(alignment:.top) { GeometryReader { proxy in Rectangle().fill(Design.accent).frame(width:proxy.size.width * (store.duration > 0 ? min(1,store.elapsed/store.duration) : 0),height:2) }.frame(height:2).accessibilityHidden(true) }
    }
}
struct PlaybackButton:View {
    @Environment(MusicStore.self) private var store
    var size:CGFloat = 32
    var body:some View {
        Button { store.togglePlayback() } label: {
            if store.isLoading { ProgressView().controlSize(.small).frame(width:size,height:size) }
            else { Image(systemName:store.isPlaying ? "pause.fill" : "play.fill").font(.system(size:size)).frame(width:size+8,height:size+8) }
        }.buttonStyle(.plain).disabled(store.current == nil).accessibilityLabel(store.isPlaying ? "Pause" : "Play").accessibilityIdentifier(store.isPlaying ? "player-pause" : "player-play")
    }
}
struct VolumeSlider:View {
    @Environment(MusicStore.self) private var store
    var body:some View { @Bindable var store = store
        HStack(spacing:8) { Image(systemName:"speaker.fill").font(.caption); Slider(value:$store.volume,in:0...1).accessibilityLabel("Volume"); Image(systemName:"speaker.wave.3.fill").font(.caption) }.foregroundStyle(.secondary)
    }
}
struct SeekControl:View {
    @Environment(MusicStore.self) private var store
    @State private var seeking = false
    @State private var position:Double = 0
    var body:some View {
        VStack(spacing:2) {
            Slider(value:Binding(get:{ seeking ? position : min(store.elapsed,max(1,store.duration)) },set:{ position = $0 }),in:0...max(1,store.duration)) { editing in
                if editing { position = store.elapsed; seeking = true }
                else { store.seek(position); seeking = false }
            }.disabled(store.duration <= 0).accessibilityLabel("Playback Position").accessibilityIdentifier("playback-seek")
            HStack { Text(time(seeking ? position : store.elapsed)).accessibilityIdentifier("elapsed-time"); Spacer(); Text("−" + time(max(0,store.duration - (seeking ? position : store.elapsed)))) }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
    func time(_ value:Double) -> String { let value = value.isFinite ? Int(max(0,value)) : 0; return String(format:"%d:%02d",value/60,value%60) }
}
struct NowPlayingView:View {
    @Environment(MusicStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var info = false
    var body:some View {
        @Bindable var store = store
        ScrollView {
            VStack(spacing:16) {
                HStack { Button { dismiss() } label: { Image(systemName:"chevron.down").font(.title3) }.buttonStyle(.plain).accessibilityLabel("Close Player").accessibilityIdentifier("close-player"); Spacer(); Text("NOW PLAYING").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.secondary); Spacer(); if let track = store.current { PlaybackWaveform(isPlaying:store.isPlaying); Menu { TrackActions(track:track) } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Track Options").accessibilityIdentifier("track-options") } }
                if let track = store.current {
                    CoverArt(title:track.work.composer,url:track.artworkURL).frame(maxWidth:260).shadow(color:.black.opacity(0.14),radius:20,y:10).padding(.vertical,8)
                    VStack(alignment:.leading,spacing:6) {
                        Text(track.work.composer).font(.subheadline).foregroundStyle(Design.accent)
                        HStack(alignment:.top) {
                            VStack(alignment:.leading,spacing:6) { Text(track.work.title).font(.system(.title2,design:.serif).weight(.semibold)); Text(track.title).font(.body).foregroundStyle(.secondary); Text(track.performer).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Button { store.favorite(track) } label: { Image(systemName:store.isFavorite(track) ? "star.fill" : "star").font(.title3) }.buttonStyle(.plain).foregroundStyle(Design.accent).accessibilityLabel("Favorite").accessibilityIdentifier("favorite-current")
                        }
                    }.frame(maxWidth:.infinity,alignment:.leading)
                    SeekControl()
                    HStack(spacing:48) { Button { store.previous() } label: { Image(systemName:"backward.fill").font(.system(size:28)) }.accessibilityLabel("Previous Track"); PlaybackButton(size:38); Button { store.next() } label: { Image(systemName:"forward.fill").font(.system(size:28)) }.accessibilityLabel("Next Track") }.buttonStyle(.plain).padding(.vertical,8)
                    VolumeSlider()
                    HStack {
                        Button { info.toggle() } label: { Image(systemName:info ? "info.circle.fill" : "info.circle") }.accessibilityLabel("Recording Information")
                        Spacer()
                        AirPlayControl().frame(width:32,height:30).accessibilityLabel("Audio Output")
                        Spacer()
                        Button { store.showQueue = true } label: { Image(systemName:"list.bullet") }.accessibilityLabel("Playing Next")
                    }.font(.title3).buttonStyle(.plain).foregroundStyle(Design.accent)
                    HStack {
                        if store.localURL(track) != nil { Label("Downloaded",systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(.secondary) }
                        else if let progress = store.downloadProgress[track.id] { ProgressView(value:progress).frame(width:100); Button("Cancel") { store.cancelDownload(track) } }
                        else { Button { store.download(track) } label: { Label(store.downloadErrors[track.id] == nil ? "Download" : "Retry Download",systemImage:"arrow.down.circle") }.accessibilityIdentifier("download-current") }
                    }
                    if let error = store.downloadErrors[track.id] { Text(error).font(.caption).foregroundStyle(.secondary) }
                    if info { VStack(alignment:.leading,spacing:10) { Text("Recording Information").font(.headline); Text(track.license).font(.caption); Link("View Source & License on IMSLP",destination:track.sourceURL).font(.subheadline) }.frame(maxWidth:.infinity,alignment:.leading).padding().background(.quaternary,in:RoundedRectangle(cornerRadius:10)) }
                } else { EmptyPanel(title:"Not Playing",icon:"music.note",message:"Select a recording to begin.") }
            }.padding(28).frame(maxWidth:460).frame(maxWidth:.infinity)
        }.background(.background)
        #if os(macOS)
        .frame(width:470,height:740)
        #endif
        .sheet(isPresented:$store.showQueue) { QueueView().environment(store) }
    }
}
struct QueueView:View {
    @Environment(MusicStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var dragging:UUID?
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Playing Next").font(.system(.title2,design:.serif).bold()); Spacer(); Button("Done") { dismiss() }.accessibilityIdentifier("close-queue") }.padding([.horizontal,.top],22)
            HStack(spacing:20) {
                Button { store.toggleShuffle() } label: { Label("Shuffle",systemImage:"shuffle").foregroundStyle(store.library.shuffle ? Design.accent : .secondary) }.accessibilityIdentifier("shuffle-mode")
                Button { store.cycleRepeat() } label: { Label(store.repeatLabel,systemImage:store.library.repeatMode == 2 ? "repeat.1" : "repeat").foregroundStyle(store.library.repeatMode == 0 ? .secondary : Design.accent) }.accessibilityIdentifier("repeat-mode")
                Spacer(); Button("Clear",role:.destructive) { store.clearQueue() }.disabled(store.library.queue.isEmpty)
            }.font(.subheadline).padding(.horizontal,22)
            if store.library.queue.isEmpty { EmptyPanel(title:"Your Queue Is Empty",icon:"music.note.list",message:"Choose Play Next or Play Last from a recording’s menu.") }
            List {
                ForEach(store.library.queue) { entry in
                    HStack {
                        if entry.id == store.currentEntry?.id { Image(systemName:"speaker.wave.2.fill").font(.caption).foregroundStyle(Design.accent) }
                        TrackRow(track:entry.track) { store.selectQueue(entry.id) }
                        Button { store.removeQueue(entry.id) } label: { Image(systemName:"minus.circle").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("Remove \(entry.track.title) from Queue")
                        #if os(macOS)
                        ReorderHandle(entry:entry,dragging:$dragging)
                        #endif
                    }.entryReorderTarget(entry.id,dragging:$dragging,entries:store.library.queue) { store.moveQueue(from:$0,to:$1) }
                }.onMove { store.moveQueue(from:$0,to:$1) }.onDelete { offsets in offsets.map { store.library.queue[$0].id }.forEach { store.removeQueue($0) } }
            }.listStyle(.plain)
            #if os(iOS)
            EditButton().padding(.horizontal,22).padding(.bottom,12)
            #endif
        }
        #if os(macOS)
        .frame(width:580,height:550)
        #endif
    }
}
#if os(macOS)
struct MiniPlayerWindow:View {
    @Environment(MusicStore.self) private var store
    var body:some View {
        VStack(spacing:14) { CoverArt(title:store.current?.work.composer ?? "IMSLP Music",url:store.current?.artworkURL).frame(width:260,height:260); Text(store.current?.title ?? "Not Playing").font(.headline).lineLimit(1); Text(store.current?.performer ?? "Choose a recording").font(.caption).foregroundStyle(.secondary).lineLimit(1); SeekControl(); HStack(spacing:36) { Button { store.previous() } label: { Image(systemName:"backward.fill") }; PlaybackButton(size:25); Button { store.next() } label: { Image(systemName:"forward.fill") } }.buttonStyle(.plain) }.padding(24).frame(width:330)
    }
}
struct AirPlayControl:NSViewRepresentable {
    func makeNSView(context:Context) -> AVRoutePickerView { AVRoutePickerView() }
    func updateNSView(_ view:AVRoutePickerView,context:Context) {}
}
#else
struct AirPlayControl:UIViewRepresentable {
    func makeUIView(context:Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.tintColor = .systemRed; return view }
    func updateUIView(_ view:AVRoutePickerView,context:Context) {}
}
#endif
