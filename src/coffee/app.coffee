require('../../bower_components/angular/angular.js')
require('../../bower_components/angular-route/angular-route.js')
require('../../bower_components/angular-sanitize/angular-sanitize.js')
require('../../bower_components/angular-animate/angular-animate.js')
require('../../bower_components/angular-cookies/angular-cookies.js')
require('../../bower_components/fhir-bower/ngFhir.js')

require('file?name=index.html!../index.html')
require('file?name=fhir.json!../fhir.json')
require('../less/app.less')

URI = require('../../bower_components/uri.js/src/URI.js')

app = require('./module')

require('./views')
require('./data')

sitemap = require('./sitemap')

parser = require('../../hl7v2fhir/src/parser')
adt2patient = require('../../hl7v2fhir/src/adt/patient')

log = require('./logger')

mkRoute = (acc, x)->
  acc.when("/#{x.name}", x)

app.config ($routeProvider) ->
  rp = $routeProvider.when '/',
    name: 'home'
    templateUrl: '/views/home.html'
    controller: 'HomeCtrl'

  rp = sitemap.main.reduce mkRoute, rp
  rp.otherwise
    templateUrl: '/views/404.html'

activate = (name)->
  sitemap.main.forEach (x)->
    if x.name == name
      x.active = true
    else
      delete x.active

app.config ($fhirProvider, $httpProvider) ->
  $fhirProvider.baseUrl = URI(window.location.search).query(true).base_uri
  $httpProvider.interceptors.push ($q, $timeout, $rootScope) ->
    request: (config) ->
      uri = URI(config.url)
      unless uri.path().match(/^\/(views|oauth)/)
        if ($rootScope.config || {}).access_token
          config.url = uri.addQuery(
            access_token: $rootScope.config.access_token
          ).toString()
      config

app.run ($rootScope, $window, $location, $http)->
  query = URI($window.location.search).query(true)
  search = $location.search()
  $rootScope.config = {
        base_uri: search.base_uri || query.base_uri
        client_id: search.client_id || query.client_id
        authorize_uri: search.authorize_uri || query.authorize_uri
        redirect_uri: $location.absUrl().replace($location.url(), '/')
        access_token: search.access_token || query.access_token
        state: search.state || query.state
                }
  $rootScope.user = {}

  if $rootScope.config.authorize_uri && !$rootScope.config.access_token
    authorizeUri = URI($rootScope.config.authorize_uri)
      .setQuery(
        client_id: $rootScope.config.client_id
        redirect_uri: $rootScope.config.redirect_uri
        response_type: 'token'
        scope: 'user'
        state: $location.path()
      ).toString()
    $window.location.href = authorizeUri
  else if $rootScope.config.access_token && $rootScope.config.base_uri
    $http.get($rootScope.config.base_uri.replace(/fhir$/, '') + 'oauth/user?access_token=' + $rootScope.config.access_token)
      .success (data) ->
        $rootScope.user.login = data.login
        $rootScope.user.scope = data.scope

  $rootScope.sitemap = sitemap
  $rootScope.$on  "$routeChangeStart", (event, next, current)->
    activate(next.name)

  if $rootScope.config.state
    $location.path($rootScope.config.state)

  $rootScope.revoke = () ->
    $http.get($rootScope.config.base.replace(/fhir$/, '') + 'oauth/revoke?access_token=' + $rootScope.config.access_token)
      .success (data) ->
        $rootScope.config = {}
        $location.url($location.path())
        $window.location.reload();

app.controller 'HomeCtrl', ($scope, $fhir)->
  $scope.header = "HomeCtrl"
  $fhir.search(type: 'Alert', query: {})
    .success (data)->
      $scope.data = data

app.controller 'PageCtrl', ($scope, $routeParams)->
  $scope.header = "PageCtrl"
  $scope.params = $routeParams
  $scope.message = 'MSH|^~\&|GHH LAB|ELAB-3|GHH OE|BLDG4|200202150930||ORU^R01|CNTRL-3456|P|2.4
PID|||555-44-4444||EVERYWOMAN^EVE^E^S^P^^L|JONES|19620320|F|||153 FERNWOOD DR.^^STATESVILLE^OH^35292||(206)3345232|(206)752-121||maritalStatus||AC555444444||67-A4335^OH^20030520||||Y|2||||DateTime|Y|
OBR|1|845439^GHH OE|1045813^GHH LAB|15545^GLUCOSE|||200202150730|||||||||'

  $scope.convert = ()->
    res = parser.parse $scope.message
    #patient = adt2patient.patient(res)
    $scope.resource = res
    #$scope.patient = patient
