JView            = require '../core/jview'
FooterView       = require '../home/footerview'
CustomLinkView   = require '../core/customlinkview'
PricingPlansView = require './plans'
MainHeaderView   = require '../core/mainheaderview'

module.exports = class PricingAppView extends JView

  getInitialState : ->

    dayOfWeek = (new Date).getDay()
    reversePlans = dayOfWeek in [2, 4, 6, 7]

    return {
      planInterval : 'year'
      promotedPlan : if reversePlans then 'developer' else 'hobbyist'
      reversePlans
    }


  constructor: (options = {}, data) ->

    options.cssClass = KD.utils.curry "content-page pricing", options.cssClass

    super options, data

    @state = KD.utils.extend @getInitialState(), options.state

    @initViews()
    @initEvents()

    { planInterval, promotedPlan } = @state

    @plans.planViews[promotedPlan].setClass 'promoted'
    @selectIntervalToggle @state.planInterval


  initViews: ->

    @mainHeader = new MainHeaderView

    @header = new KDCustomHTMLView
      partial   : "Our pricing, your terms"
      tagName   : "h4"
      cssClass  : "pricing-heading"

    @headerDescription = new KDCustomHTMLView
      tagName   : 'p'
      cssClass  : 'pricing-description'
      partial   : "
        Get started for free or go right into high gear with one of our paid plans.
        Our simple pricing is designed to help you get the most out of your Koding experience.
        Trusted by your peers worldwide.
      "

    @intervalToggle = new KDButtonGroupView
      cssClass     : 'interval-toggle'
      buttons      :
        'month'    :
          title    : 'MONTHLY'
          callback : => @emit 'IntervalToggleChanged', { planInterval : 'month' }
        'year'     :
          title    : 'YEARLY'
          callback : => @emit 'IntervalToggleChanged', { planInterval : 'year' }

    @plans = new PricingPlansView { @state }

    @footer = @initFooter()

    @kodingFooter = new FooterView


  initEvents: ->
    @plans.on 'PlanSelected', @bound 'planSelected'

    @on 'IntervalToggleChanged', @bound 'handleToggleChanged'


  initFooter: ->

    features = [
      'Full sudo access'
      'VMs hosted on Amazon EC2'
      'SSH Access'
      'Unlimited workspaces'

      'Custom sub-domains'
      'Publicly accessible IP'
      'Ubuntu 14.04'
      'Built-in IDE and Terminal'

      'Realtime collaboration'
      'Audio/Video in collaboration'
      'Custom IDE shortcuts'
      'Connect your own VM'
    ]

    footer = new KDCustomHTMLView
      cssClass : 'pricing-footer'

    footer.addSubView new KDCustomHTMLView
      tagName : 'h4'
      partial : 'All plans include:'

    footer.addSubView featuresWrapper = new KDCustomHTMLView
      tagName  : 'ul'
      cssClass : 'features clearfix'

    features.forEach (feature) ->
      featuresWrapper.addSubView new KDCustomHTMLView
        tagName  : 'li'
        cssClass : 'single-feature'
        partial  : feature

    footer.addSubView new CustomLinkView
      title    : 'Learn more about all our features'
      cssClass : 'learn-more'
      href     : '/Features'

    footer.addSubView new KDCustomHTMLView
      cssClass : 'footer-msg'
      partial  : "
        <p>Don't worry, you can upgrade or downgrade your plan at any time.</p>
        <p class='footer-note'>(you can cancel a yearly plan within 3 months -
        no questions asked! outside of 3 months there is 2 month fee.)</p>
      "

    return footer


  selectIntervalToggle: (planInterval) ->
    button = @intervalToggle.buttons[planInterval]
    @intervalToggle.buttonReceivedClick button


  handleToggleChanged: ({ planInterval }) ->

    @state.planInterval = planInterval

    @selectIntervalToggle planInterval

    @plans.switchTo planInterval


  planSelected: (options) ->

    { router } = KD.singletons

    query = [
      "/Login"
      "?redirectTo=Pricing"
      "&planTitle=#{options.planTitle}"
      "&planInterval=#{@state.planInterval}"
    ].join ""

    router.handleRoute query

  setState: (obj) -> @state = KD.utils.extend @state, obj


  pistachio: ->
    """
      {{> @mainHeader}}
      {{> @header}}
      {{> @headerDescription}}
      {{> @intervalToggle}}
      {{> @plans}}
      {{> @footer}}
      {{> @kodingFooter}}
    """