import SwiftUI

struct HomeView:View {
    @Environment(MusicStore.self) private var store
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:28) {
                PageHeading(title:"Home",subtitle:"Your world of classical music.")
                ViewThatFits(in:.horizontal) {
                    HStack(spacing:24) { welcome; CoverArt(title:"Johann Sebastian Bach").frame(width:210,height:210).rotationEffect(.degrees(4)).padding(12) }
                    welcome
                }.padding(26).frame(maxWidth:.infinity,alignment:.leading).background(Design.color("Bach").opacity(0.08),in:RoundedRectangle(cornerRadius:16))
                if !store.library.recent.isEmpty {
                    Text("Recently Played").font(.title2.bold())
                    ScrollView(.horizontal,showsIndicators:false) {
                        HStack(alignment:.top,spacing:18) {
                            ForEach(store.library.recent.prefix(8)) { track in
                                Button { store.play([track]) } label: {
                                    VStack(alignment:.leading,spacing:8) { CoverArt(title:track.work.composer,url:track.artworkURL).frame(width:158); Text(track.work.title).font(.subheadline.weight(.medium)).lineLimit(2); Text(track.performer).font(.caption).foregroundStyle(.secondary).lineLimit(1) }.frame(width:158,alignment:.leading)
                                }.buttonStyle(.plain).contextMenu { TrackActions(track:track) }
                            }
                        }
                    }
                }
                HStack { Text("Explore Composers").font(.title2.bold()); Spacer(); Button("See All") { store.section = .browse } }
                ComposerGrid(composers:Array(IMSLPClient.featuredComposers.prefix(4)))
                if !store.library.tracks.isEmpty {
                    Text("From Your Library").font(.title2.bold())
                    ForEach(store.library.tracks.prefix(4)) { track in TrackRow(track:track) { store.play([track]) } }
                }
                Text("Public recordings, enduring performances. Discover the music in the IMSLP collection.").font(.footnote).foregroundStyle(.secondary).padding(.bottom,12)
            }.padding(28).frame(maxWidth:1100,alignment:.leading).frame(maxWidth:.infinity)
        }.navigationTitle("")
    }
    var welcome:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("THE OPEN CLASSICAL COLLECTION").font(.system(size:10,weight:.semibold)).tracking(1.8).foregroundStyle(Design.accent)
            Text("Great music.\nYours to discover.").font(.system(.largeTitle,design:.serif)).fixedSize(horizontal:false,vertical:true)
            Text("Find a composer. Explore a work.\nMake a performance your own.").font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            NavigationLink(value:Work.from(IMSLPClient.sampleTitle)) { Label("Explore Bach’s Cello Suites",systemImage:"arrow.right") }.buttonStyle(.borderedProminent).controlSize(.large).padding(.top,4)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
struct ComposerGrid:View {
    let composers:[Composer]
    var body:some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:145,maximum:230),spacing:20)],alignment:.leading,spacing:24) {
            ForEach(composers) { composer in
                NavigationLink(value:composer) {
                    VStack(alignment:.leading,spacing:10) { CoverArt(title:composer.name); Text(composer.name).font(.subheadline.weight(.medium)).lineLimit(2) }
                }.buttonStyle(.plain)
            }
        }
    }
}
struct BrowseView:View {
    @State private var catalog:[Composer] = []
    @State private var loading = false
    @State private var failure:String?
    @State private var offset = 0
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                PageHeading(title:"Browse",subtitle:"Discover music by composer.")
                ComposerGrid(composers:IMSLPClient.featuredComposers)
                Divider().padding(.vertical,6)
                Text("The IMSLP Directory").font(.title2.bold())
                Text("Composers, performers, and contributors from the source catalog.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(catalog) { composer in NavigationLink(value:composer) { HStack { Image(systemName:"person.crop.square").foregroundStyle(Design.accent); Text(composer.name); Spacer(); Image(systemName:"chevron.right").foregroundStyle(.tertiary) }.padding(.vertical,6) }.buttonStyle(.plain) }
                if let failure { Text(failure).foregroundStyle(.secondary) }
                Button { load() } label: { if loading { ProgressView() } else { Text(catalog.isEmpty ? "Open Composer Directory" : "Load More") } }.disabled(loading)
            }.padding(28).frame(maxWidth:1100,alignment:.leading).frame(maxWidth:.infinity)
        }
    }
    private func load() {
        loading = true; failure = nil
        Task {
            do { let people = try await IMSLPClient.shared.people(start:offset); catalog.append(contentsOf:people.filter { person in !catalog.contains(where:{$0.id == person.id}) }); offset += people.count }
            catch { failure = error.localizedDescription }
            loading = false
        }
    }
}
struct SearchView:View {
    @State private var query = ""
    @State private var results = SearchResults()
    @State private var loading = false
    @State private var failure:String?
    @State private var completedQuery = ""
    @FocusState private var searchFocused:Bool
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                PageHeading(title:"Search",subtitle:"Find a composer, work, or catalog number.")
                HStack(spacing:10) {
                    Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                    TextField("Composers, works, and more",text:$query).textFieldStyle(.plain).font(.body).accessibilityIdentifier("search-field").autocorrectionDisabled().focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("Clear Search") }
                }.padding(13).background(.quaternary.opacity(0.6),in:RoundedRectangle(cornerRadius:10))
                if loading { HStack { ProgressView().controlSize(.small); Text("Searching IMSLP…").foregroundStyle(.secondary) } }
                if let failure {
                    EmptyPanel(title:failure == "No Internet Connection" ? failure : "Search Unavailable",icon:"wifi.slash",message:failure)
                    Button("Try Again") { Task { await search() } }
                } else if query.isEmpty {
                    Text("Discover").font(.title2.bold())
                    ForEach(["Bach", "Beethoven", "Chopin", "BWV 1007", "Clair de lune"],id:\.self) { text in Button { query = text } label: { HStack { Text(text).font(.title3); Spacer(); Image(systemName:"arrow.up.left").font(.caption) }.padding(.vertical,8) }.buttonStyle(.plain).foregroundStyle(Design.accent) }
                } else if !loading, !completedQuery.isEmpty, results.works.isEmpty, results.composers.isEmpty {
                    EmptyPanel(title:"No Results",icon:"magnifyingglass",message:"Try a composer name, work title, or catalog number.")
                } else {
                    if !results.composers.isEmpty {
                        Text("Composers & People").font(.title2.bold())
                        ForEach(results.composers) { composer in NavigationLink(value:composer) { HStack(spacing:12) { Image(systemName:"person.crop.circle.fill").font(.largeTitle).foregroundStyle(Design.accent.opacity(0.7)); Text(composer.name); Spacer(); Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary) }.padding(.vertical,5) }.buttonStyle(.plain) }
                    }
                    if !results.works.isEmpty { Text("Works").font(.title2.bold()) }
                    LazyVStack(spacing:0) {
                        ForEach(Array(results.works.enumerated()),id:\.element.id) { index,work in
                            NavigationLink(value:work) { WorkRow(work:work) }.buttonStyle(.plain).accessibilityIdentifier("work-result-\(index)")
                            Divider()
                        }
                    }
                    if let offset = results.nextOffset { Button("Load More") { Task { await more(offset) } }.disabled(loading) }
                }
            }.padding(28).frame(maxWidth:1000,alignment:.leading).frame(maxWidth:.infinity)
        }.scrollDismissesKeyboard(.interactively).task(id:query) { await search() }
    }
    private func search() async {
        let term = query
        failure = nil
        guard !term.trimmingCharacters(in:.whitespaces).isEmpty else { results = SearchResults(); loading = false; completedQuery = ""; return }
        loading = true
        do {
            try await Task.sleep(for:.milliseconds(300))
            let found = try await IMSLPClient.shared.search(term)
            try Task.checkCancellation()
            guard query == term else { return }
            results = found; completedQuery = term; loading = false
        } catch is CancellationError { }
        catch { guard query == term, !Task.isCancelled else { return }; failure = error.localizedDescription; loading = false }
    }
    private func more(_ offset:Int) async {
        let term = query; loading = true
        do {
            let found = try await IMSLPClient.shared.search(term,offset:offset)
            guard query == term else { return }
            results.works.append(contentsOf:found.works.filter { work in !results.works.contains(where:{$0.id == work.id}) }); results.nextOffset = found.nextOffset
        } catch { if query == term { failure = error.localizedDescription } }
        if query == term { loading = false }
    }
}
struct ComposerView:View {
    var composer:Composer
    @State private var works:[Work] = []
    @State private var loading = true
    @State private var failure:String?
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                PageHeading(title:composer.name,subtitle:"Works from IMSLP")
                Link("View Composer on IMSLP",destination:composer.sourceURL).font(.subheadline)
                if loading { ProgressView().frame(maxWidth:.infinity,minHeight:160) }
                if let failure { EmptyPanel(title:"Could Not Load Works",icon:"wifi.exclamationmark",message:failure) }
                if !loading, works.isEmpty, failure == nil { EmptyPanel(title:"No Works Listed",icon:"music.note",message:"This person may be a performer or contributor. Open their source page for more details.") }
                LazyVStack(spacing:0) { ForEach(works) { work in NavigationLink(value:work) { WorkRow(work:work) }.buttonStyle(.plain); Divider() } }
            }.padding(28).frame(maxWidth:1000,alignment:.leading).frame(maxWidth:.infinity)
        }.task { do { works = try await IMSLPClient.shared.works(for:composer) } catch { failure = error.localizedDescription }; loading = false }
    }
}
struct WorkDetailView:View {
    @Environment(MusicStore.self) private var store
    let work:Work
    @State private var detail:WorkDetail?
    @State private var failure:String?
    @State private var showSynthesized = false
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                ViewThatFits(in:.horizontal) {
                    HStack(alignment:.center,spacing:28) { CoverArt(title:work.composer).frame(width:190,height:190); heading.frame(minWidth:240) }
                    VStack(alignment:.leading,spacing:20) { CoverArt(title:work.composer).frame(width:150,height:150); heading }
                }
                Divider()
                HStack { Text("Recordings").font(.title2.bold()); Spacer(); if let detail { Text("\(detail.recordings.filter { !$0.isSynthesized }.count) performances").font(.subheadline).foregroundStyle(.secondary) } }
                if let detail {
                    if detail.recordings.isEmpty { EmptyPanel(title:"No Audio Recordings",icon:"music.note",message:"This work has no supported recording entries. You can check the original IMSLP page.") }
                    ForEach(Array(detail.recordings.enumerated()).filter { !$0.element.isSynthesized },id:\.element.id) { index,recording in recordingCard(recording,index:index) }
                    if detail.recordings.contains(where: \.isSynthesized) {
                        DisclosureGroup("Synthesized / MIDI",isExpanded:$showSynthesized) {
                            VStack(spacing:20) { ForEach(Array(detail.recordings.enumerated()).filter { $0.element.isSynthesized },id:\.element.id) { index,recording in recordingCard(recording,index:index) } }.padding(.top,15)
                        }.font(.headline)
                    }
                } else if let failure {
                    EmptyPanel(title:"Recordings Unavailable",icon:"exclamationmark.triangle",message:failure)
                    Button("Try Again") { Task { await load() } }
                } else { ProgressView("Loading recordings…").frame(maxWidth:.infinity,minHeight:160) }
                Link("View this work on IMSLP",destination:work.sourceURL).font(.footnote).padding(.vertical)
            }.padding(28).frame(maxWidth:1050,alignment:.leading).frame(maxWidth:.infinity)
        }.task { await load() }
    }
    var heading:some View {
        VStack(alignment:.leading,spacing:12) { Text(work.composer.uppercased()).font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(Design.accent); Text(work.title).font(.system(.title,design:.serif).weight(.semibold)).fixedSize(horizontal:false,vertical:true); Text("Choose a performance").foregroundStyle(.secondary); ShareLink(item:work.sourceURL) { Label("Share Work",systemImage:"square.and.arrow.up") }.font(.subheadline) }.frame(maxWidth:.infinity,alignment:.leading)
    }
    func recordingCard(_ recording:Recording,index:Int) -> some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.top,spacing:14) {
                CoverArt(title:work.composer,url:recording.artworkURL,compact:true).frame(width:52,height:52)
                VStack(alignment:.leading,spacing:4) { Text(recording.performer).font(.headline); Text(recording.title).font(.subheadline).foregroundStyle(.secondary); if recording.isSynthesized { Text("Synthesized recording").font(.caption).foregroundStyle(Design.accent) } }
                Spacer()
                if let first = recording.tracks.first, recording.tracks.allSatisfy({ $0.needsSourceAccess && store.localURL($0) == nil }) {
                    Link(destination:first.sourceURL) { Label("Open IMSLP",systemImage:"arrow.up.right.square") }.buttonStyle(.bordered).accessibilityIdentifier("source-recording-\(index)")
                } else {
                    Button { store.play(recording.tracks) } label: { Label("Play",systemImage:"play.fill") }.buttonStyle(.borderedProminent).accessibilityIdentifier("play-recording-\(index)")
                }
                Menu { Button("Play Next") { store.enqueue(recording.tracks,next:true) }; Button("Play Last") { store.enqueue(recording.tracks,next:false) }; Button("Add to Library") { recording.tracks.forEach { store.save($0) } }; Button("Download Recording") { recording.tracks.forEach { store.download($0) } } } label: { Image(systemName:"ellipsis").frame(width:20,height:28) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Recording Options")
            }
            VStack(spacing:0) { ForEach(Array(recording.tracks.enumerated()),id:\.element.id) { number,track in TrackRow(track:track,number:number+1) { store.play(recording.tracks,at:number) }; if number < recording.tracks.count-1 { Divider().padding(.leading,36) } } }
            Text(recording.license).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
            if let track = recording.tracks.first, track.needsSourceAccess {
                Text("Website access required" + (track.accessRegion.map { " · IMSLP source: \($0)" } ?? "") + ". No public player link is provided.").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("source-access-\(index)")
            }
        }.padding(18).background(.quaternary.opacity(0.35),in:RoundedRectangle(cornerRadius:12))
    }
    func load() async { failure = nil; do { detail = try await IMSLPClient.shared.work(work) } catch { failure = error.localizedDescription } }
}
