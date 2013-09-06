'*****************************************************************
'**  Media Browser Roku Client - Home Page
'*****************************************************************


'**********************************************************
'** Show Home Page
'**********************************************************

Function ShowHomePage()

    ' Create Grid Screen
    screen = CreateGridScreen("", m.curUserProfile.Title, "two-row-flat-landscape-custom")

    ' Get Item Counts
    itemCounts = GetItemCounts()

    If itemCounts=invalid Then
        ShowError("Error", "Could Not Get Data From Server")
        return false
    End If

    ' Setup Globals
    m.movieToggle = ""
    m.tvToggle    = ""
    m.musicToggle = ""

    ' Setup Row Data
    screen.rowNames   = CreateObject("roArray", 3, true)
    screen.rowStyles  = CreateObject("roArray", 3, true)
    screen.rowContent = CreateObject("roArray", 3, true)

    If itemCounts.MovieCount > 0 Then
        AddGridRow(screen, "Movies", "landscape")
    End If

    If itemCounts.SeriesCount > 0 Then
        AddGridRow(screen, "TV", "landscape")
    End If

    If itemCounts.SongCount > 0 Then
        AddGridRow(screen, "Music", "landscape")
    End If

    AddGridRow(screen, "Options", "landscape")

    ShowGridNames(screen)

    ' Get Data
    If itemCounts.MovieCount > 0 Then
        moviesButtons = GetMoviesButtons()
        AddGridRowContent(screen, moviesButtons)
    End If

    If itemCounts.SeriesCount > 0 Then
        tvButtons = GetTVButtons()
        AddGridRowContent(screen, tvButtons)
    End If

    If itemCounts.SongCount > 0 Then
        musicButtons = GetMusicButtons()
        AddGridRowContent(screen, musicButtons)
    End If

    optionButtons = GetOptionsButtons()
    AddGridRowContent(screen, optionButtons)

    ' Show Screen
    screen.Screen.Show()

    ' Hide Description Popup
    screen.Screen.SetDescriptionVisible(false)

    while true
        msg = wait(0, screen.Screen.GetMessagePort())

        if type(msg) = "roGridScreenEvent" Then
            if msg.isListFocused() then

            else if msg.isListItemSelected() Then
                row = msg.GetIndex()
                selection = msg.getData()

                Debug("Content type: " + screen.rowContent[row][selection].ContentType)

                If screen.rowContent[row][selection].ContentType = "MovieLibrary" Then
                    ShowMoviesListPage()

                Else If screen.rowContent[row][selection].ContentType = "MovieToggle" Then
                    ' Toggle Movie Display
                    GetNextMovieToggle()
                    moviesButtons = GetMoviesButtons()
                    UpdateGridRowContent(screen, row, moviesButtons)

                Else If screen.rowContent[row][selection].ContentType = "Movie" Then
                    ShowMoviesDetailPage(screen.rowContent[row][selection].Id)

                Else If screen.rowContent[row][selection].ContentType = "TVLibrary" Then
                    ShowTVShowListPage()

                Else If screen.rowContent[row][selection].ContentType = "TVToggle" Then
                    ' Toggle TV Display
                    GetNextTVToggle()
                    tvButtons = GetTVButtons()
                    UpdateGridRowContent(screen, row, tvButtons)

                Else If screen.rowContent[row][selection].ContentType = "Episode" Then
                    ShowTVDetailPage(screen.rowContent[row][selection].Id)

                Else If screen.rowContent[row][selection].ContentType = "MusicLibrary" Then
                    ShowMusicListPage()

                Else If screen.rowContent[row][selection].ContentType = "SwitchUser" Then
                    RegDelete("userId")
                    Debug("Switch User")
                    return true

                Else If screen.rowContent[row][selection].ContentType = "Preferences" Then
                    ShowPreferencesPage()

                Else 
                    Debug("Unknown Type found")
                End If
            Else If msg.isScreenClosed() Then
                Debug("Close home screen")
                return false
            End If
        end if
    end while

    return false
End Function


'**********************************************************
'** Get Item Counts From Server
'**********************************************************

Function GetItemCounts() As Object
    request = CreateURLTransferObjectJson(GetServerBaseUrl() + "/Items/Counts?UserId=" + m.curUserProfile.Id, true)

    if (request.AsyncGetToString())
        while (true)
            msg = wait(0, request.GetPort())

            if (type(msg) = "roUrlEvent")
                code = msg.GetResponseCode()

                if (code = 200)
                    jsonData = ParseJSON(msg.GetString())
                    return jsonData
                else
                    Debug("Failed to Get Item Counts")
                    return invalid
                end if
            else if (event = invalid)
                request.AsyncCancel()
            end if
        end while
    end if

    Return invalid
End Function


'**********************************************************
'** Get Movie Buttons Row
'**********************************************************

Function GetMoviesButtons() As Object
    ' Set the Default movie library button
    buttons = [
        {
            Title: "Movie Library"
            ContentType: "MovieLibrary"
            ShortDescriptionLine1: "Movie Library"
            HDPosterUrl: "pkg://images/items/MovieTile_HD.png"
            SDPosterUrl: "pkg://images/items/MovieTile_SD.png"
        }
    ]

    switchButton = [
        {
            Title: "Toggle Movie"
            ContentType: "MovieToggle"
            ShortDescriptionLine1: "Toggle Display"
        }
    ]

    ' Initialize Movie Metadata
    MovieMetadata = InitMovieMetadata()

    If m.movieToggle = "latest" Then
        switchButton[0].HDPosterUrl = "pkg://images/items/Toggle_Latest_HD.png"
        switchButton[0].SDPosterUrl = "pkg://images/items/Toggle_Latest_SD.png"

        ' Get Latest Unwatched Movies
        recentMovies = MovieMetadata.GetLatest()
        If recentMovies<>invalid
            buttons.Append( switchButton )
            buttons.Append( recentMovies )
        End if

    Else If m.movieToggle = "favorite" Then
        switchButton[0].HDPosterUrl = "pkg://images/items/Toggle_Favorites_HD.png"
        switchButton[0].SDPosterUrl = "pkg://images/items/Toggle_Favorites_SD.png"

        buttons.Append( switchButton )

    Else
        switchButton[0].HDPosterUrl = "pkg://images/items/Toggle_Resume_HD.png"
        switchButton[0].SDPosterUrl = "pkg://images/items/Toggle_Resume_SD.png"

        ' Check For Resumable Movies, otherwise default to latest
        resumeMovies = MovieMetadata.GetResumable()
        If resumeMovies<>invalid And resumeMovies.Count() > 0
            buttons.Append( switchButton )
            buttons.Append( resumeMovies )
        Else
            m.movieToggle = "latest"

            ' Override Image
            switchButton[0].HDPosterUrl = "pkg://images/items/Toggle_Latest_HD.png"
            switchButton[0].SDPosterUrl = "pkg://images/items/Toggle_Latest_SD.png"

            ' Get Latest Unwatched Movies
            recentMovies = MovieMetadata.GetLatest()
            If recentMovies<>invalid
                buttons.Append( switchButton )
                buttons.Append( recentMovies )
            End if
        End if

    End If

    Return buttons
End Function


'**********************************************************
'** Get Next Movie Toggle
'**********************************************************

Function GetNextMovieToggle()
    If m.movieToggle = "latest" Then
        m.movieToggle = "favorite"
    Else If m.movieToggle = "favorite" Then
        m.movieToggle = "resume"
    Else
        m.movieToggle = "latest"
    End If
End Function


'**********************************************************
'** Get TV Buttons Row
'**********************************************************

Function GetTVButtons() As Object
    ' Set the Default movie library button
    buttons = [
        {
            Title: "TV Library"
            ContentType: "TVLibrary"
            ShortDescriptionLine1: "TV Library"
            HDPosterUrl: "pkg://images/items/TVTile_HD.png"
            SDPosterUrl: "pkg://images/items/TVTile_SD.png"
        }
    ]

    switchButton = [
        {
            Title: "Toggle TV"
            ContentType: "TVToggle"
            ShortDescriptionLine1: "Toggle Display"
        }
    ]

    ' Initialize TV Metadata
    TvMetadata = InitTvMetadata()

    If m.tvToggle = "latest" Then
        switchButton[0].HDPosterUrl = "pkg://images/items/Toggle_Latest_HD.png"
        switchButton[0].SDPosterUrl = "pkg://images/items/Toggle_Latest_SD.png"

        ' Get Latest Unwatched TV
        recentTV = TvMetadata.GetLatest()
        If recentTV<>invalid
            buttons.Append( switchButton )
            buttons.Append( recentTV )
        End if

    Else If m.tvToggle = "favorite" Then
        switchButton[0].HDPosterUrl = "pkg://images/items/Toggle_Favorites_HD.png"
        switchButton[0].SDPosterUrl = "pkg://images/items/Toggle_Favorites_SD.png"

        buttons.Append( switchButton )

    Else

        switchButton[0].HDPosterUrl = "pkg://images/items/Toggle_Resume_HD.png"
        switchButton[0].SDPosterUrl = "pkg://images/items/Toggle_Resume_SD.png"

        ' Check For Resumable TV, otherwise default to latest
        resumeTV = TvMetadata.GetResumable()
        If resumeTV<>invalid And resumeTV.Count() > 0
            buttons.Append( switchButton )
            buttons.Append( resumeTV )
        Else
            m.tvToggle = "latest"

            ' Override Image
            switchButton[0].HDPosterUrl = "pkg://images/items/Toggle_Latest_HD.png"
            switchButton[0].SDPosterUrl = "pkg://images/items/Toggle_Latest_SD.png"

            ' Get Latest Unwatched TV
            recentTV = TvMetadata.GetLatest()
            If recentTV<>invalid
                buttons.Append( switchButton )
                buttons.Append( recentTV )
            End if
        End if

    End If

    Return buttons
End Function


'**********************************************************
'** Get Next TV Toggle
'**********************************************************

Function GetNextTVToggle()
    If m.tvToggle = "latest" Then
        m.tvToggle = "favorite"
    Else If m.tvToggle = "favorite" Then
        m.tvToggle = "resume"
    Else
        m.tvToggle = "latest"
    End If
End Function


'**********************************************************
'** Get Music Buttons Row
'**********************************************************

Function GetMusicButtons() As Object
    ' Set the Default Music library button
    buttons = [
        {
            Title: "Music Library"
            ContentType: "MusicLibrary"
            ShortDescriptionLine1: "Music Library"
            HDPosterUrl: "pkg://images/items/MusicTile_HD.png"
            SDPosterUrl: "pkg://images/items/MusicTile_SD.png"
        }
    ]

    switchButton = [
        {
            Title: "Toggle Music"
            ContentType: "MusicToggle"
            ShortDescriptionLine1: "Toggle Display"
        }
    ]

    Return buttons
End Function


'**********************************************************
'** Get Options Buttons Row
'**********************************************************

Function GetOptionsButtons() As Object
    ' Set the Options buttons
    buttons = [
        {
            Title: "Switch User"
            ContentType: "SwitchUser"
            ShortDescriptionLine1: "Switch User"
            HDPosterUrl: "pkg://images/items/SwitchUsersTile_HD.png"
            SDPosterUrl: "pkg://images/items/SwitchUsersTile_SD.png"
        },
        {
            Title: "Preferences"
            ContentType: "Preferences"
            ShortDescriptionLine1: "Preferences"
            ShortDescriptionLine2: "Version " + getGlobalVar("channelVersion", "Unknown")
            HDPosterUrl: "pkg://images/items/PreferencesTile_HD.png"
            SDPosterUrl: "pkg://images/items/PreferencesTile_SD.png"
        }
    ]

    Return buttons
End Function
