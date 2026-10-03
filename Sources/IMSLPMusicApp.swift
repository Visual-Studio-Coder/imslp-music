import SwiftUI

@main struct IMSLPMusicApp:App {
    @State private var store = MusicStore()
    var body:some Scene {
        WindowGroup {
            RootView().environment(store).tint(Design.accent)
            #if os(macOS)
                .frame(minWidth:840,minHeight:600)
            #endif
        }
        #if os(macOS)
        .defaultSize(width:1180,height:790)
        .commands {
            CommandGroup(after:.newItem) {
                Button("Search IMSLP") { store.navigationPath = NavigationPath(); store.section = .search }.keyboardShortcut("f",modifiers:.command)
            }
            CommandMenu("Playback") {
                Button(store.isPlaying ? "Pause" : "Play") { store.togglePlayback() }.keyboardShortcut(.space,modifiers:[])
                Button("Next Track") { store.next() }.keyboardShortcut(.rightArrow,modifiers:.command)
                Button("Previous Track") { store.previous() }.keyboardShortcut(.leftArrow,modifiers:.command)
                Divider()
                Button("Playing Next") { store.showQueue.toggle() }.keyboardShortcut("u",modifiers:[.command,.option])
            }
        }
        #endif
        #if os(macOS)
        Window("Mini Player",id:"mini-player") {
            MiniPlayerWindow().environment(store).tint(Design.accent)
        }.defaultSize(width:360,height:440).windowResizability(.contentSize)
        #endif
    }
}
struct RootView:View {
    @Environment(MusicStore.self) private var store
    @Environment(\.openURL) private var openURL
    var body:some View {
        @Bindable var store = store
        Group {
            #if os(macOS)
            VStack(spacing:0) {
            NavigationSplitView {
                VStack(alignment:.leading,spacing:16) {
                    HStack(spacing:8) { Image(systemName:"music.note").foregroundStyle(Design.accent); Text("IMSLP Music").font(.system(.title3,design:.serif).weight(.semibold)) }.padding(.horizontal,18).padding(.top,22)
                    ScrollView {
                        VStack(alignment:.leading,spacing:4) {
                            Text("Discover").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal,12).padding(.bottom,6)
                            ForEach(AppSection.allCases) { item in
                                Button { store.navigationPath = NavigationPath(); store.section = item } label: {
                                    Label(item.rawValue,systemImage:item.icon).font(.body).foregroundStyle(store.section == item ? Design.accent : .primary).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,12).padding(.vertical,10).contentShape(Rectangle())
                                }.buttonStyle(.plain).background(store.section == item ? Design.accent.opacity(0.10) : Color.clear,in:RoundedRectangle(cornerRadius:7)).accessibilityIdentifier("nav-\(item.rawValue.lowercased())")
                            }
                            if !store.library.playlists.isEmpty {
                                Text("Playlists").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal,12).padding(.top,22).padding(.bottom,6)
                                ForEach(store.library.playlists) { playlist in
                                    Button { store.section = .library; store.navigationPath = NavigationPath(); store.navigationPath.append(playlist.id) } label: { Label(playlist.name,systemImage:"music.note.list").frame(maxWidth:.infinity,alignment:.leading).padding(12).contentShape(Rectangle()) }.buttonStyle(.plain)
                                }
                            }
                        }.padding(.horizontal,10)
                    }
                    VStack(alignment:.leading,spacing:4) { Text("THE CLASSICAL COLLECTION").font(.system(size:9,weight:.semibold)).tracking(1); Text("Music from IMSLP").font(.caption).foregroundStyle(.secondary) }.padding(20)
                }.navigationSplitViewColumnWidth(min:185,ideal:215,max:260)
            } detail: {
                NavigationStack(path:$store.navigationPath) { SectionPage(section:store.section) }.id(store.section)
            }
            PlayerBar()
            }
            #else
            TabView(selection:$store.section) {
                ForEach(AppSection.allCases) { section in
                    VStack(spacing:0) {
                        NavigationStack { SectionPage(section:section) }
                        if store.current != nil { PlayerBar() }
                    }
                        .tabItem { Label(section.rawValue,systemImage:section.icon) }.tag(section)

                }
            }
            #endif
        }
        .sheet(isPresented:$store.showPlayer) { NowPlayingView().environment(store).tint(Design.accent) }
        .sheet(isPresented:Binding(get:{ store.showQueue && !store.showPlayer },set:{ store.showQueue = $0 })) { QueueView().environment(store).tint(Design.accent) }
        .alert("Music Unavailable",isPresented:Binding(get:{store.error != nil},set:{if !$0 { store.error = nil }})) {
            if let source = store.errorSource { Button("Open IMSLP") { openURL(source); store.error = nil } }
            Button("OK",role:.cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}
struct SectionPage:View {
    let section:AppSection
    var body:some View {
        Group {
            switch section {
            case .home: HomeView()
            case .browse: BrowseView()
            case .search: SearchView()
            case .library: LibraryView()
            }
        }
        .navigationDestination(for:Work.self) { WorkDetailView(work:$0) }
        .navigationDestination(for:Composer.self) { ComposerView(composer:$0) }
        .navigationDestination(for:UUID.self) { PlaylistView(id:$0) }
    }
}
