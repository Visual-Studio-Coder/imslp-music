import SwiftUI

enum AppSection:String,CaseIterable,Identifiable {
    case home = "Home", browse = "Browse", library = "Library", search = "Search"
    var id:String { rawValue }
    var icon:String { switch self { case .home: "house"; case .browse: "square.grid.2x2"; case .library: "music.note.list"; case .search: "magnifyingglass" } }
}
enum Design {
    static let accent = Color("AccentColor")
    static let colors:[Color] = [Color(red:0.14,green:0.28,blue:0.30), Color(red:0.36,green:0.23,blue:0.22), Color(red:0.29,green:0.29,blue:0.40), Color(red:0.43,green:0.35,blue:0.21), Color(red:0.22,green:0.32,blue:0.40), Color(red:0.36,green:0.25,blue:0.35)]
    static func color(_ text:String) -> Color { colors[text.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % colors.count }] }
}
struct CoverArt:View {
    var title:String
    var url:URL? = nil
    var compact = false
    var body:some View {
        ZStack {
            LinearGradient(colors:[Design.color(title).opacity(0.8),Design.color(title)],startPoint:.topLeading,endPoint:.bottomTrailing)
            Canvas { context,size in
                let center = CGPoint(x:size.width*0.76,y:size.height*0.34)
                for n in 0..<9 {
                    let radius = size.width * (0.15 + Double(n)*0.072)
                    let rect = CGRect(x:center.x-radius,y:center.y-radius,width:radius*2,height:radius*2)
                    context.stroke(Path(ellipseIn:rect),with:.color(.white.opacity(0.1)),lineWidth:0.8)
                }
                for n in 0..<5 {
                    var p = Path(); p.move(to:CGPoint(x:0,y:size.height*0.64 + CGFloat(n)*size.height*0.033)); p.addLine(to:CGPoint(x:size.width,y:size.height*0.44 + CGFloat(n)*size.height*0.033))
                    context.stroke(p,with:.color(.white.opacity(0.12)),lineWidth:1)
                }
            }
            if compact { Image(systemName:"music.note").font(.title3).foregroundStyle(.white.opacity(0.9)) }
            else {
                VStack(alignment:.leading,spacing:8) {
                    HStack { Text("IMSLP").font(.system(size:10,weight:.semibold,design:.serif)).tracking(3); Spacer(); Image(systemName:"waveform").font(.caption) }
                    Spacer()
                    Text(title.components(separatedBy:",").first ?? title).font(.system(size:25,weight:.regular,design:.serif)).lineLimit(3).minimumScaleFactor(0.6)
                    Rectangle().frame(width:30,height:1).opacity(0.65)
                    Text("CLASSICAL COLLECTION").font(.system(size:7,weight:.medium)).tracking(2)
                }.padding(20).foregroundStyle(.white.opacity(0.95))
            }
            if let url { AsyncImage(url:url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear } }
        }.aspectRatio(1,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:compact ? 5 : 9))
        .accessibilityHidden(true)
    }
}
struct PageHeading:View {
    var title:String
    var subtitle:String? = nil
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            Text(title).font(.system(.largeTitle,design:.serif).weight(.bold)).accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
struct EmptyPanel:View {
    var title:String
    var icon:String
    var message:String
    var body:some View { ContentUnavailableView(title,systemImage:icon,description:Text(message)).frame(maxWidth:.infinity,minHeight:240) }
}
struct WorkRow:View {
    let work:Work
    var body:some View {
        HStack(spacing:14) {
            CoverArt(title:work.composer,compact:true).frame(width:48,height:48)
            VStack(alignment:.leading,spacing:4) { Text(work.title).font(.body.weight(.medium)).lineLimit(2); Text(work.composer).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
            Spacer(); Image(systemName:"chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.padding(.vertical,7).contentShape(Rectangle())
    }
}
struct TrackActions:View {
    @Environment(MusicStore.self) private var store
    var track:Track
    var body:some View {
        Button("Play",systemImage:"play.fill") { store.play([track]) }
        Button("Play Next",systemImage:"text.line.first.and.arrowtriangle.forward") { store.enqueue([track],next:true) }
        Button("Play Last",systemImage:"text.line.last.and.arrowtriangle.forward") { store.enqueue([track],next:false) }
        Divider()
        Button(store.isFavorite(track) ? "Undo Favorite" : "Favorite",systemImage:store.isFavorite(track) ? "star.fill" : "star") { store.favorite(track) }
        if store.isSaved(track) { Button("Remove from Library",systemImage:"minus.circle",role:.destructive) { store.removeFromLibrary(track) } }
        else { Button("Add to Library",systemImage:"plus") { store.save(track) } }
        Menu("Add to Playlist",systemImage:"text.badge.plus") {
            if store.library.playlists.isEmpty { Text("Create a playlist in Library") }
            ForEach(store.library.playlists) { playlist in Button(playlist.name) { store.add(track,to:playlist.id) } }
        }
        if store.localURL(track) != nil { Button("Remove Download",systemImage:"trash") { store.removeDownload(track) } }
        else if store.downloadProgress[track.id] != nil { Button("Cancel Download",systemImage:"xmark") { store.cancelDownload(track) } }
        else { Button("Download",systemImage:"arrow.down.circle") { store.download(track) } }
        Divider()
        Link("View on IMSLP",destination:track.sourceURL)
        ShareLink(item:track.sourceURL)
    }
}
struct TrackRow:View {
    @Environment(MusicStore.self) private var store
    @Environment(\.openURL) private var openURL
    var track:Track
    var number:Int? = nil
    var play:() -> Void
    var body:some View {
        HStack(spacing:12) {
            Button { if track.needsSourceAccess && store.localURL(track) == nil { openURL(track.sourceURL) } else { play() } } label: {
                HStack(spacing:12) {
                    if let number { Text(String(number)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).frame(width:24) }
                    else { CoverArt(title:track.work.composer,url:track.artworkURL,compact:true).frame(width:42,height:42) }
                    VStack(alignment:.leading,spacing:4) {
                        Text(track.title).font(.body).foregroundStyle(store.current?.id == track.id ? Design.accent : .primary).lineLimit(2)
                        Text(number == nil ? track.work.title : track.performer).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength:4)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            if track.needsSourceAccess && store.localURL(track) == nil { Image(systemName:"arrow.up.right.square").foregroundStyle(.secondary).accessibilityLabel("Open recording on IMSLP") }
            if store.isFavorite(track) { Image(systemName:"star.fill").font(.caption).foregroundStyle(Design.accent).accessibilityLabel("Favorite") }
            if store.localURL(track) != nil { Image(systemName:"arrow.down.circle.fill").foregroundStyle(.secondary).accessibilityLabel("Downloaded") }
            if let value = store.downloadProgress[track.id] { ProgressView(value:value).frame(width:30) }
            if store.current?.id == track.id { PlaybackWaveform(isPlaying:store.isPlaying) }
            Menu { TrackActions(track:track) } label: { Image(systemName:"ellipsis").frame(width:28,height:32) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More options for \(track.title)")
        }.padding(.vertical,7).contextMenu { TrackActions(track:track) }
    }
}

struct PlaybackWaveform:View {
    let isPlaying:Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        TimelineView(.animation(minimumInterval:1.0/12.0,paused:!isPlaying || reduceMotion)) { context in
            HStack(alignment:.center,spacing:2) {
                ForEach(0..<4) { index in
                    Capsule().fill(Design.accent).frame(width:2.5,height:height(index,at:context.date))
                }
            }.frame(width:18,height:20)
        }
        .accessibilityElement(children:.ignore)
        .accessibilityLabel(isPlaying ? "Playing" : "Paused")
        .accessibilityIdentifier("playback-waveform")
    }
    private func height(_ index:Int,at date:Date) -> CGFloat {
        guard isPlaying else { return 3 }
        guard !reduceMotion else { return [8,16,11,6][index] }
        let phase = date.timeIntervalSinceReferenceDate * (4.5 + Double(index) * 0.7) + Double(index) * 1.8
        return CGFloat(4 + 13 * (sin(phase) + 1) / 2)
    }
}

#if os(macOS)
struct ReorderHandle:View {
    let entry:QueueEntry
    @Binding var dragging:UUID?
    var body:some View {
        Image(systemName:"line.3.horizontal")
            .foregroundStyle(.secondary).frame(width:24,height:32).contentShape(Rectangle())
            .onDrag { dragging = entry.id; return NSItemProvider(object:entry.id.uuidString as NSString) }
            .accessibilityLabel("Reorder \(entry.track.title)")
            .accessibilityIdentifier("reorder-\(entry.track.title)")
            .help("Drag to change track order")
    }
}
#endif
extension View {
    @ViewBuilder func entryReorderTarget(_ id:UUID, dragging:Binding<UUID?>, entries:[QueueEntry], move:@escaping (IndexSet,Int) -> Void) -> some View {
        #if os(macOS)
        self.onDrop(of:["public.text"],isTargeted:nil) { _ in
            defer { dragging.wrappedValue = nil }
            guard let source = dragging.wrappedValue,
                  let from = entries.firstIndex(where:{$0.id == source}),
                  let target = entries.firstIndex(where:{$0.id == id}), from != target else { return false }
            move(IndexSet(integer:from),target > from ? target + 1 : target)
            return true
        }
        #else
        self
        #endif
    }
}
