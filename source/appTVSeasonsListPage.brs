'*****************************************************************
'**  Media Browser Roku Client - TV Show Seasons List Page
'*****************************************************************


'**********************************************************
'** Show TV Show Seasons List Page
'**********************************************************

Function ShowTVSeasonsListPage(seriesInfo As Object) As Integer
    ' Setup Screen
    port   = CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)

    screen.SetBreadcrumbText(seriesInfo.Title, "TV")
    screen.SetListStyle("flat-episodic-16x9")
    screen.SetListDisplayMode("scale-to-fill")

    ' Initialize TV Metadata
    TvMetadata = InitTvMetadata()

    ' Get Data
    seasonData = TvMetadata.GetSeasons(seriesInfo.Id)

    seasonIds   = seasonData[0]
    seasonNames = seasonData[1]

    ' Set Season Names
    screen.SetListNames(seasonNames)


    ' Fetch Season 1
    episodeData = TvMetadata.GetEpisodes(seasonIds[0])
    screen.SetContentList(episodeData)

    ' Show Screen
    screen.Show()

    ' Only fetch theme music if turned on
    If RegRead("prefTVMusic") = "yes" Then
        ' Fetch Theme Music
        themeMusic = TvMetadata.GetThemeMusic(seriesInfo.Id)

        If themeMusic<>invalid And themeMusic.Count() <> 0 Then
            Debug("playing theme music")
            ' Create Audio Player
            player = CreateAudioPlayer()

            ' Add Theme Music To Playlist
            player.AddPlaylist(themeMusic)

            ' Repeat Playlist if turned on
            If RegRead("prefTVMusicLoop") = "yes" Then
                ' Loop
                player.Repeat(true)
            Else
                ' Only Playthrough Once
                player.Repeat(false)
            End If

            ' Start Playing
            player.Play(0)
        Else
            player = invalid
        End If

    Else
        player = invalid
    End If

    while true
        msg = wait(0, screen.GetMessagePort())

        if type(msg) = "roPosterScreenEvent" Then
            If msg.isListFocused() Then
                m.curSeason = msg.GetIndex()
                m.curShow   = 0

                screen.SetContentList([])
                screen.SetFocusedListItem(m.curShow)
                screen.ShowMessage("Retrieving")

                ' Fetch New Season
                episodeData = TvMetadata.GetEpisodes(seasonIds[Msg.GetIndex()])
                screen.SetContentList(episodeData)

                screen.ClearMessage()
            Else If msg.isListItemSelected() Then
                selection = msg.GetIndex()

                episodeIndex = ShowTVDetailPage(episodeData[msg.GetIndex()].Id, episodeData, selection, player)
                screen.SetFocusedListItem(episodeIndex)

            Else If msg.isScreenClosed() then
                return -1
            End If
        end if
    end while

    return 0
End Function
