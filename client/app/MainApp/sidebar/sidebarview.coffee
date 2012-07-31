class Sidebar extends JView

  constructor:->

    super

    account           = KD.whoami()
    {profile}         = account
    @_onDevelop       = no
    @_finderExpanded  = no
    @_popupIsActive   = no

    @avatar = new AvatarView
      tagName    : "div"
      cssClass   : "avatar-image-wrapper"
      bind       : "mouseenter mouseleave"
      mouseenter : => @animateLeftNavIn()
      mouseleave : => @animateLeftNavOut()
      size       :
        width    : 160
        height   : 76
    , account

    @avatarAreaIconMenu = new AvatarAreaIconMenu
      delegate     : @
      bind         : "mouseenter mouseleave"
      mouseenter   : => @animateLeftNavIn()
      mouseleave   : => @animateLeftNavOut()

    @navController = new NavigationController
      view           : new NavigationList
        type         : "navigation"
        subItemClass : NavigationLink
        bind         : "mouseenter mouseleave"
        mouseenter   : => @animateLeftNavIn()
        mouseleave   : => @animateLeftNavOut()
      wrapper        : no
      scrollView     : no
    , navItems

    @nav = @navController.getView()

    @accNavController = new NavigationController
      view           : new NavigationList
        type         : "navigation"
        cssClass     : "account"
        subItemClass : NavigationLink
        bind         : "mouseenter mouseleave"
        mouseenter   : => @animateLeftNavIn()
        mouseleave   : => @animateLeftNavOut()
      wrapper        : no
      scrollView     : no
    , accNavItems

    @accNav = @accNavController.getView()

    @adminNavController = new NavigationController
      view           : new NavigationList
        type         : "navigation"
        cssClass     : "account admin"
        subItemClass : AdminNavigationLink
        bind         : "mouseenter mouseleave"
        mouseenter   : => @animateLeftNavIn()
        mouseleave   : => @animateLeftNavOut()
      wrapper        : no
      scrollView     : no

    @adminNav = @adminNavController.getView()

    @resetAdminNavController()

    @finderHeader = new KDCustomHTMLView
      tagName   : "h2"
      pistachio : "{{#(profile.nickname)}}.#{location.hostname}"
    , account

    @finderResizeHandle = new SidebarResizeHandle
      cssClass  : "finder-resize-handle"

    @finderController = new NFinderController
      fsListeners : yes
      initialPath : "/Users/#{profile.nickname}/Sites/#{profile.nickname}.koding.com/website" # obsolete, make it work this way
      initDelay   : 5000
      useStorage  : yes

    @finder = @finderController.getView()

    @finderBottomControlsController = new KDListViewController
      view        : new FinderBottomControls
      wrapper     : no
      scrollView  : no
    , bottomControlsItems

    @finderBottomControls = @finderBottomControlsController.getView()

    @listenWindowResize()

  resetAdminNavController:->
    @utils.wait 1000, =>
      @adminNavController.removeAllItems()
      if KD.isLoggedIn()
        KD.whoami().fetchRole? (err, role)=>
          if role is "super-admin"
            @adminNavController.instantiateListItems adminNavItems.items

  setListeners:->

    mainView = @getDelegate()
    {@contentPanel, @sidebarPanel} = mainView

    @getSingleton('mainController').on "AvatarPopupIsActive", =>
      @_popupIsActive = yes

    @getSingleton('mainController').on "AvatarPopupIsInactive", =>
      @_popupIsActive = no

    $fp = @$('#finder-panel')
    cp  = @contentPanel
    @wc = @getSingleton "windowController"
    fpLastWidth = null

    @finderResizeHandle.on "ClickedButNotDragged", =>
      unless fpLastWidth
        fpLastWidth = parseInt $fp.css("width"), 10
        cp.$().css left : 65, width : @wc.winWidth - 65
        @utils.wait 300, -> $fp.css "width", 13
      else
        fpLastWidth = 208 if fpLastWidth < 100
        $fp.css "width", fpLastWidth
        cp.$().css left : 52 + fpLastWidth, width : @wc.winWidth - 52 - fpLastWidth
        fpLastWidth = null

    @finderResizeHandle.on "DragStarted", (e, dragState)=>
      cp._left  = parseInt cp.$().css("left"), 10
      cp._left  = parseInt cp.$().css("left"), 10
      @_fpWidth = parseInt $fp.css("width"), 10
      cp._width = parseInt @wc.winWidth - 52 - @_fpWidth
      cp.unsetClass "transition"

    @finderResizeHandle.on "DragFinished", (e, dragState)=>
      delete cp._left
      delete cp._width
      delete @_fpWidth
      unless @finderResizeHandle._dragged
        @finderResizeHandle.emit "ClickedButNotDragged"
      else
        fpLastWidth = null
      delete @finderResizeHandle._dragged
      cp.setClass "transition"

    @finderResizeHandle.on "DragInAction", (x, y)=>
      @finderResizeHandle._dragged = yes
      newFpWidth = @_fpWidth - x
      return if newFpWidth < 13
      cp.$().css left : cp._left - x, width : cp._width + x
      $fp.css "width", newFpWidth

  viewAppended:->

    super

    @setListeners()

  render:(account)->

    account or= KD.whoami()

    @avatar.setData account
    @avatar.render()
    @finderHeader.setData account
    @finderHeader.render()

    @navController.reset()
    @accNavController.reset()
    @resetAdminNavController()

    @avatarAreaIconMenu.accountChanged account

    @finderController.reset()

    super

  pistachio:->

    """
    <div id="main-nav">
      <div class="avatar-placeholder">
        <div id="avatar-area">
          {{> @avatar}}
        </div>
      </div>
      {{> @avatarAreaIconMenu}}
      {{> @nav}}
      <hr>
      {{> @accNav}}
      {{> @adminNav}}
    </div>
    <div id='finder-panel'>
      {{> @finderResizeHandle}}
      <div id='finder-header-holder'>
        {{> @finderHeader}}
      </div>
      <div id='finder-holder'>
        {{> @finder}}
      </div>
      <div id='finder-bottom-controls'>
        {{> @finderBottomControls}}
      </div>
    </div>
    """
  _mouseenterTimeout = null
  _mouseleaveTimeout = null

  animateLeftNavIn:->

    return if $('body').hasClass("dragInAction")
    @utils.killWait _mouseleaveTimeout if _mouseleaveTimeout
    _mouseenterTimeout = @utils.wait 200, =>
      @_mouseentered = yes
      @expandNavigationPanel() if @_onDevelop

  animateLeftNavOut:->

    return if @_popupIsActive or $('body').hasClass("dragInAction")
    @utils.killWait _mouseenterTimeout if _mouseenterTimeout
    _mouseleaveTimeout = @utils.wait 200, =>
      if @_mouseentered and @_onDevelop
        @collapseNavigationPanel()

  expandNavigationPanel:(newSize, callback)->

    @$('.avatar-placeholder').removeClass "collapsed"
    @$('#finder-panel').removeClass "expanded"
    if parseInt(@contentPanel.$().css("left"), 10) < 174
      @contentPanel.setClass "mouse-on-nav"
    @utils.wait 300, => callback?()

  collapseNavigationPanel:(callback)->

    @$('.avatar-placeholder').addClass "collapsed"
    @$('#finder-panel').addClass "expanded"
    @contentPanel.unsetClass "mouse-on-nav"
    @utils.wait 300, =>
      callback?()
      @emit "NavigationPanelWillCollapse"

  expandEnvironmentSplit:(newSize, callback)->

    newSize          = 260
    @_finderExpanded = yes

    @contentPanel.setClass "with-finder"
    @contentPanel.unsetClass "social"
    @contentPanel.setWidth @wc.winWidth - @$('#finder-panel').width() - 52
    @utils.wait 300, =>
      callback?()
      @_windowDidResize()

  collapseEnvironmentSplit:(callback)->

    @contentPanel.unsetClass "with-finder"
    @contentPanel.setClass "social"
    @contentPanel.setWidth @wc.winWidth - 160
    @utils.wait 300, =>
      @_finderExpanded = no
      callback?()

  showEnvironmentPanel:->

    @showFinderPanel()

  showFinderPanel:->

    unless @_finderExpanded
      @collapseNavigationPanel()
      @expandEnvironmentSplit null, ()=> @_onDevelop = yes

  hideFinderPanel:->

    if @_finderExpanded
      @expandNavigationPanel 160, ()=> @_onDevelop = no
      @collapseEnvironmentSplit =>
        @utils.wait 300, => @notifyResizeListeners()

  _windowDidResize:->

    {winWidth} = @getSingleton('windowController')
    if KD.isLoggedIn()
      if @contentPanel.$().hasClass "with-finder"
        @contentPanel.setWidth winWidth - parseInt(@$('#finder-panel').css("width"), 10) - 52
      else
        @contentPanel.setWidth winWidth - 160
    else
      @contentPanel.setWidth winWidth

    bottomListHeight = @$("#finder-bottom-controls").height() or 109
    @$("#finder-holder").height @getHeight() - @$("#finder-header-holder").height() - bottomListHeight

  navItems =
    id    : "navigation"
    title : "navigation"
    items : [
        title : "Activity"
      ,
        title : "Topics"
      ,
        title : "Members"
      ,
        title : "Develop",        loggedIn : yes,  path : "StartTab"
      ,
        title : "Apps"
    ]

  accNavItems =
    id    : "acc-navigation"
    title : "acc-navigation"
    items : [
        title : "Invite Friends", loggedIn : yes
      ,
        title : "Account",        loggedIn : yes
      ,
        title : "Logout",         loggedIn : yes,  action : "logout",
      ,
        title : "Login",          loggedOut : yes, action : "login"
    ]

  bottomControlsItems =
    id : "finder-bottom-controls"
    items : [
        title : "Launch Terminal",    icon : "terminal",    path : "Shell"
      ,
        title : "Add Resources",      icon : "resources"
      ,
        title : "Settings",           icon : "cog"
      ,
        title : "Keyboard Shortcuts", icon : "shortcuts",   action: "showShortcuts"
    ]

  adminNavItems =
    id    : "admin-navigation"
    title : "admin-navigation"
    items : [
        title : "Kite selector", loggedIn : yes, callback : -> new KiteSelectorModal
    ]


class KiteSelectorModal extends KDModalView

  constructor: (options = {}, data) ->

    options.title = "Select kites"

    super options, data

    @putTable()


  putTable:->

    KD.whoami().fetchAllKites (err, kites)=>
      if err
        new KDNotificationView
          title : err.message
        @destroy()
      else
        i = 1
        for own name, kite of kites
          sanitizeHosts = (hosts)->
            selectOptions = []
            hosts.forEach (host)->
              selectOptions.push
                value : host
                title : host
            return selectOptions

          selectOptions = sanitizeHosts kite.hosts

          @addSubView field = new KDView
            cssClass : "modalformline"

          field.addSubView new KDLabelView
            title    : name

          field.addSubView new KDSelectBox
            selectOptions : selectOptions
            cssClass      : "fr"
            defaultValue  : "cl#{i}"
            callback      : do ->
              kiteName = name
              (value)-> log value, kiteName, "selected kite"
          i++






