'*****************************************************************
'**  Media Browser Roku Client - Movies Detail Page
'*****************************************************************


'**********************************************************
'** Show Movies Details Page
'**********************************************************

Function ShowMoviesDetailPage(movieId As String, movieList=invalid, movieIndex=invalid) As Integer

    if validateParam(movieId, "roString", "ShowMoviesDetailPage") = false return -1

    ' Handle Direct Access from Home
    If movieIndex=invalid Then
        movieIndex = 0
    End If
    
    ' Setup Screen
    port   = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(port)

    screen.SetBreadcrumbText("", "Movies")
    screen.SetDescriptionStyle("movie")
    screen.SetStaticRatingEnabled(false)

    ' Fetch / Refresh Screen Details
    moviesDetails = RefreshMoviesDetailPage(screen, movieId)

    ' Remote key id's for left/right navigation
    remoteKeyLeft  = 4
    remoteKeyRight = 5
 
    while true
        msg = wait(0, screen.GetMessagePort())

        if type(msg) = "roSpringboardScreenEvent" then
            If msg.isRemoteKeyPressed() 
                ' Only allow left/right navigation if movieList provided
                If movieList<>invalid Then
                    If msg.GetIndex() = remoteKeyLeft Then
                        movieIndex = getPreviousMovie(movieList, movieIndex)

                        If movieIndex <> -1
                            movieId = movieList[movieIndex].Id
                            moviesDetails = RefreshMoviesDetailPage(screen, movieId)
                        End If
                    Else If msg.GetIndex() = remoteKeyRight
                        movieIndex = getNextMovie(movieList, movieIndex)

                        If movieIndex <> -1
                            movieId = movieList[movieIndex].Id
                            moviesDetails = RefreshMoviesDetailPage(screen, movieId)
                        End If
                    End If
                End If
            Else If msg.isButtonPressed()
                Debug("ButtonPressed")
                If msg.GetIndex() = 1
                    ' Set Saved Play Status
                    If moviesDetails.PlaybackPosition<>"" And moviesDetails.PlaybackPosition<>"0" Then
                        PlayStart = (moviesDetails.PlaybackPosition).ToFloat()

                        ' Only update URLs if not direct play
                        If Not moviesDetails.IsDirectPlay Then
                            ' Update URLs for Resume
                            moviesDetails.StreamData = AddResumeOffset(moviesDetails.StreamData, moviesDetails.PlaybackPosition)
                        End If
                    Else
                        PlayStart = 0
                    End If

                    showVideoScreen(moviesDetails, PlayStart)
                    moviesDetails = RefreshMoviesDetailPage(screen, movieId)
                End If
                If msg.GetIndex() = 2
                    ' Show Error Dialog For Unsupported video types - Should be temporary call
                    If moviesDetails.DoesExist("StreamData")=false
                        ShowDialog("Playback Error", "That video type is not playable yet.", "Back")
                    Else
                        PlayStart = 0
                        showVideoScreen(moviesDetails, PlayStart)
                        moviesDetails = RefreshMoviesDetailPage(screen, movieId)
                    End If
                End If
                If msg.GetIndex() = 3
                    ShowMoviesChaptersPage(moviesDetails)
                    moviesDetails = RefreshMoviesDetailPage(screen, movieId)
                End If
            Else If msg.isScreenClosed()
                Debug("Screen closed")
                Exit While
            End If
        Else
            Debug("Unexpected message class: " + type(msg))
        End If
    end while

    return movieIndex
End Function


'**********************************************************
'** Get Movie Details From Server
'**********************************************************

Function GetMoviesDetails(movieId As String) As Object

    if validateParam(movieId, "roString", "GetMoviesDetails") = false return -1

    request = CreateURLTransferObjectJson(GetServerBaseUrl() + "/Users/" + m.curUserProfile.Id + "/Items/" + movieId, true)

    Debug("Movie URL: " + request.GetUrl())

    if (request.AsyncGetToString())
        while (true)
            msg = wait(0, request.GetPort())

            if (type(msg) = "roUrlEvent")
                code = msg.GetResponseCode()

                if (code = 200)
                    ' Fixes bug within BRS Json Parser
                    regex = CreateObject("roRegex", Chr(34) + "(RunTimeTicks|PlaybackPositionTicks|StartPositionTicks)" + Chr(34) + ":([0-9]+),", "i")
                    fixedString = regex.ReplaceAll(msg.GetString(), Chr(34) + "\1" + Chr(34) + ":" + Chr(34) + "\2" + Chr(34) + ",")

                    itemData = ParseJSON(fixedString)

                    ' Convert Data For Page
                    movieData = {
                        Id: itemData.Id
                        ContentId: itemData.Id
                        ContentType: "Movie"
                        Title: itemData.Name
                        Description: itemData.Overview
                        Rating: itemData.OfficialRating
                        StarRating: itemData.CriticRating
                        Watched: itemData.UserData.Played
                    }

                    ' Check For Production Year
                    If Type(itemData.ProductionYear) = "Integer" Then
                        movieData.ReleaseDate = Stri(itemData.ProductionYear)
                    End if

                    ' Check For Run Time
                    itemRunTime = itemData.RunTimeTicks
                    If itemRunTime<>"" And itemRunTime<>invalid
                        movieData.Length = Int(((itemRunTime).ToFloat() / 10000) / 1000)
                    End If

                    ' Check For Playback Position Time
                    itemPlaybackPositionTime = itemData.UserData.PlaybackPositionTicks
                    If itemPlaybackPositionTime<>"" And itemPlaybackPositionTime<>invalid
                        movieData.PlaybackPosition = itemPlaybackPositionTime
                    End If

                    ' Check If Item has Image, otherwise use default
                    If itemData.ImageTags.Primary<>"" And itemData.ImageTags.Primary<>invalid
                        movieData.HDPosterUrl = GetServerBaseUrl() + "/Items/" + itemData.Id + "/Images/Primary/0?quality=90&height=212&width=&EnableImageEnhancers=false&tag=" + itemData.ImageTags.Primary
                        movieData.SDPosterUrl = GetServerBaseUrl() + "/Items/" + itemData.Id + "/Images/Primary/0?quality=90&height=142&width=&EnableImageEnhancers=false&tag=" + itemData.ImageTags.Primary
                    Else 
                        movieData.HDPosterUrl = "pkg://images/items/collection.png"
                        movieData.SDPosterUrl = "pkg://images/items/collection.png"
                    End If

                    ' Check For People, Grab First 3 If Exists
                    If itemData.People<>invalid And itemData.People.Count() > 0
                        movieData.Actors = CreateObject("roArray", 10, true)

                        maxPeople = itemData.People.Count()-1

                        ' Check To Max sure there are 3 people
                        If maxPeople > 3
                            maxPeople = 2
                        End If

                        For i = 0 to maxPeople
                            If itemData.People[i].Name<>"" And itemData.People[i].Name<>invalid
                                movieData.Actors.Push(itemData.People[i].Name)
                            End If
                        End For
                    End If

                    ' Check Media Streams For HD Video And Surround Sound Audio
                    streamInfo = GetStreamInfo(itemData.MediaStreams)

                    movieData.HDBranded = streamInfo.isHDVideo
                    movieData.IsHD = streamInfo.isHDVideo

                    If streamInfo.isSSAudio=true
                        movieData.AudioFormat = "dolby-digital"
                    End If

                    ' Setup Video Player
                    streamData = SetupVideoStreams(movieId, itemData.VideoType, itemData.Path)

                    If streamData<>invalid
                        movieData.StreamData = streamData

                        ' Determine Direct Play
                        If StreamData.Stream<>invalid Then
                            movieData.IsDirectPlay = true
                        Else
                            movieData.IsDirectPlay = false
                        End If

                    End If

                    ' Setup Watched
                    If itemData.UserData.Played<>invalid And itemData.UserData.Played=true
                        If itemData.UserData.LastPlayedDate<>invalid
                            movieData.Categories = "Watched on " + formatDateStamp(itemData.UserData.LastPlayedDate)
                        Else
                            movieData.Categories = "Watched"
                        End If
                    End If

                    ' Setup Chapters
                    If itemData.Chapters<>invalid
                        movieData.Chapters = CreateObject("roArray", 3, true)
                        chapterCount = 0
                        For each chapterData in itemData.Chapters
                            chapterList = {
                                Title: chapterData.Name
                                ShortDescriptionLine1: chapterData.Name
                                ShortDescriptionLine2: FormatChapterTime(chapterData.StartPositionTicks)
                                StartPositionTicks: chapterData.StartPositionTicks
                            }

                            ' Check If Chapter has Image, otherwise use default
                            If chapterData.ImageTag<>"" And chapterData.ImageTag<>invalid
                                chapterList.HDPosterUrl = GetServerBaseUrl() + "/Items/" + itemData.Id + "/Images/Chapter/" + itostr(chapterCount) + "?quality=90&height=141&width=&EnableImageEnhancers=false&tag=" + chapterData.ImageTag
                                chapterList.SDPosterUrl = GetServerBaseUrl() + "/Items/" + itemData.Id + "/Images/Chapter/" + itostr(chapterCount) + "?quality=90&height=94&width=&EnableImageEnhancers=false&tag=" + chapterData.ImageTag
                            Else 
                                chapterList.HDPosterUrl = "pkg://images/items/collection.png"
                                chapterList.SDPosterUrl = "pkg://images/items/collection.png"
                            End If

                            chapterCount = chapterCount + 1
                            movieData.Chapters.push(chapterList)
                        End For
                    End If

                    return movieData
                Else
					debug("Failed to get movie details")
                    Return invalid
                End If
            Else If (event = invalid)
                request.AsyncCancel()
            End If
        end while
    endif

    Return invalid
End Function


'**************************************************************
'** Refresh the Contents of the Movies Detail Page
'**************************************************************

Function RefreshMoviesDetailPage(screen As Object, movieId As String) As Object

    if validateParam(screen, "roSpringboardScreen", "RefreshMoviesDetailPage") = false return -1
    if validateParam(movieId, "roString", "RefreshMoviesDetailPage") = false return -1

    ' Get Data
    moviesDetails = GetMoviesDetails(movieId)

    ' Setup Buttons
    screen.ClearButtons()

    If moviesDetails.PlaybackPosition<>"" And moviesDetails.PlaybackPosition<>"0" Then
        screen.AddButton(1, "Resume playing")
        screen.AddButton(2, "Play from beginning")
    Else
        screen.AddButton(2, "Play")
    End If

    screen.AddButton(3, "View Chapters")

    ' Show Screen
    screen.SetContent(moviesDetails)
    screen.Show()

    Return moviesDetails
End Function


'**********************************************************
'** Get Next Movie from List
'**********************************************************

Function getNextMovie(movieList As Object, movieIndex As Integer) As Integer

    if validateParam(movieList, "roArray", "getNextMovie") = false return -1

    nextIndex = movieIndex + 1
    if nextIndex >= movieList.Count() Or nextIndex < 0 then
       nextIndex = 0 
    end if

    movie = movieList[nextIndex]

    if validateParam(movie, "roAssociativeArray", "getNextMovie") = false return -1 

    return nextIndex

End Function


'**********************************************************
'** Get Previous Movie from List
'**********************************************************

Function getPreviousMovie(movieList As Object, movieIndex As Integer) As Integer

    if validateParam(movieList, "roArray", "getPreviousMovie") = false return -1 

    prevIndex = movieIndex - 1
    if prevIndex < 0 or prevIndex >= movieList.Count() then
        if movieList.Count() > 0 then
            prevIndex = movieList.Count() - 1 
        else
            return -1
        end if
    end if

    movie = movieList[prevIndex]

    if validateParam(movie, "roAssociativeArray", "getPreviousMovie") = false return -1 

    return prevIndex

End Function
