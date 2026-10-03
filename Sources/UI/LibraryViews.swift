import SwiftUI

struct LibraryView:View {
    @Environment(MusicStore.self) private var store
    @State private var filter = "All Music"
    @State private var sort = "Recently Added"
    @State private var creating = false
    @State private var name = ""
    var tracks:[Track] {
        let source = filter == "Downloaded" ? (store.library.downloadedTracks ?? store.library.tracks) : store.library.tracks
        let tracks = source.filter { track in filter == "Favorites" ? store.isFavorite(track) : filter == "Downloaded" ? store.localURL(track) != nil : true }
        return sort == "Title" ? tracks.sorted { $0.work.title.localizedStandardCompare($1.work.title) == .orderedAscending } : tracks
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack { PageHeading(title:"Library",subtitle:"The music you make your own."); Button { name = ""; creating = true } label: { Label("New Playlist",systemImage:"plus") }.accessibilityIdentifier("new-playlist") }
                if !store.library.playlists.isEmpty {
                    Text("Playlists").font(.title2.bold())
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:140,maximum:190),spacing:18)],alignment:.leading,spacing:20) {
                        ForEach(store.library.playlists) { playlist in
                            NavigationLink(value:playlist.id) {
                                VStack(alignment:.leading,spacing:8) { CoverArt(title:playlist.name); Text(playlist.name).font(.headline); Text("\(playlist.entries.count) tracks").font(.caption).foregroundStyle(.secondary) }
                            }.buttonStyle(.plain).accessibilityIdentifier("playlist-\(playlist.name)")
                        }
                    }
                }
                HStack {
                    Picker("Show",selection:$filter) { ForEach(["All Music","Favorites","Downloaded"],id:\.self) { Text($0) } }.pickerStyle(.segmented).frame(maxWidth:430)
                    Spacer()
                    Menu { Picker("Sort",selection:$sort) { Text("Recently Added").tag("Recently Added"); Text("Title").tag("Title") } } label: { Image(systemName:"arrow.up.arrow.down").accessibilityLabel("Sort Library") }
                }
                if tracks.isEmpty { EmptyPanel(title:filter == "Downloaded" ? "No Downloads" : "Your Library Starts Here",icon:filter == "Downloaded" ? "arrow.down.circle" : "music.note.list",message:filter == "Downloaded" ? "Download recordings to listen without an internet connection." : "Add a recording or mark a favorite while you explore IMSLP.") }
                else { LazyVStack(spacing:0) { ForEach(tracks) { track in TrackRow(track:track) { store.play(tracks,at:tracks.firstIndex(of:track) ?? 0) }; Divider() } } }
                if !store.library.downloads.isEmpty {
                    HStack { Image(systemName:"internaldrive"); Text("\(ByteCountFormatter.string(fromByteCount:store.downloadedBytes,countStyle:.file)) downloaded on this device") }.font(.footnote).foregroundStyle(.secondary)
                }
                if !store.downloadErrors.isEmpty {
                    VStack(alignment:.leading,spacing:8) {
                        Text("Download Needs Attention").font(.headline)
                        ForEach(store.downloadErrors.keys.sorted(),id:\.self) { key in Text(store.downloadErrors[key] ?? "").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }.padding(28).frame(maxWidth:1050,alignment:.leading).frame(maxWidth:.infinity)
        }.sheet(isPresented:$creating) { PlaylistNameSheet(title:"New Playlist",name:$name) { store.createPlaylist(name); creating = false } }
    }
}
struct PlaylistNameSheet:View {
    @Environment(\.dismiss) private var dismiss
    var title:String
    @Binding var name:String
    var save:() -> Void
    var body:some View {
        VStack(alignment:.leading,spacing:22) {
            Text(title).font(.system(.title2,design:.serif).bold())
            TextField("Playlist Name",text:$name).textFieldStyle(.roundedBorder).accessibilityIdentifier("playlist-name").onSubmit { if !name.trimmingCharacters(in:.whitespaces).isEmpty { save() } }
            HStack { Button("Cancel",role:.cancel) { dismiss() }; Spacer(); Button("Save",action:save).buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityIdentifier("save-playlist") }
        }.padding(28).frame(minWidth:300,idealWidth:380).presentationDetents([.height(220)])
    }
}
struct PlaylistView:View {
    @Environment(MusicStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id:UUID
    @State private var renaming = false
    @State private var confirmingDelete = false
    @State private var name = ""
    var playlist:MusicPlaylist? { store.library.playlists.first { $0.id == id } }
    @State private var dragging:UUID?
    var body:some View {
        if let playlist {
            VStack(alignment:.leading,spacing:20) {
                HStack(spacing:22) {
                    CoverArt(title:playlist.name).frame(width:120,height:120)
                    VStack(alignment:.leading,spacing:12) {
                        Text("PLAYLIST").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(Design.accent)
                        Text(playlist.name).font(.system(.largeTitle,design:.serif).bold())
                        HStack { Button { store.play(playlist.entries.map(\.track)) } label: { Label("Play",systemImage:"play.fill") }.buttonStyle(.borderedProminent).disabled(playlist.entries.isEmpty)
                            Menu {
                                Button("Rename") { name = playlist.name; renaming = true }
                                Button("Download All") { playlist.entries.forEach { store.download($0.track) } }
                                Button("Play Next") { store.enqueue(playlist.entries.map(\.track),next:true) }
                                Button("Delete Playlist",role:.destructive) { confirmingDelete = true }
                            } label: { Image(systemName:"ellipsis.circle") }.accessibilityLabel("Playlist Options").accessibilityIdentifier("playlist-options")
                        }
                    }; Spacer()
                }.padding([.horizontal,.top],24)
                if playlist.entries.isEmpty { EmptyPanel(title:"Add Your First Track",icon:"music.note",message:"Open a recording’s menu and choose Add to Playlist.") }
                else {
                    List {
                        ForEach(playlist.entries) { entry in
                            HStack {
                                TrackRow(track:entry.track) { store.play(playlist.entries.map(\.track),at:playlist.entries.firstIndex(of:entry) ?? 0) }
                                Button { store.removePlaylistTrack(id,entry:entry.id) } label: { Image(systemName:"minus.circle").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("Remove from Playlist").accessibilityIdentifier("remove-playlist-track")
                                #if os(macOS)
                                ReorderHandle(entry:entry,dragging:$dragging)
                                #endif
                            }.entryReorderTarget(entry.id,dragging:$dragging,entries:playlist.entries) { store.movePlaylist(id,from:$0,to:$1) }
                                .contextMenu { Button("Remove from Playlist",role:.destructive) { store.removePlaylistTrack(id,entry:entry.id) } }
                        }.onMove { store.movePlaylist(id,from:$0,to:$1) }.onDelete { offsets in offsets.map { playlist.entries[$0].id }.forEach { store.removePlaylistTrack(id,entry:$0) } }
                    }.listStyle(.plain)
                }
                Spacer(minLength:0)
            }.sheet(isPresented:$renaming) { PlaylistNameSheet(title:"Rename Playlist",name:$name) { store.renamePlaylist(id,name:name); renaming = false } }
                .confirmationDialog("Delete this playlist?",isPresented:$confirmingDelete,titleVisibility:.visible) { Button("Delete Playlist",role:.destructive) { store.deletePlaylist(id); dismiss() } } message: { Text("Your saved music and downloads will remain in your library.") }
                #if os(iOS)
                .toolbar { EditButton() }
                #endif
        }
    }
}
