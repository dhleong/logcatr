'use strict'

# Declare app level module which depends on filters, and services
App = angular.module('app', [
  'ngCookies'
  'ngResource'
  'ngRoute'
  'app.services'
  'app.controllers'
  'app.directives'
  'app.filters'
  'partials'
])

App.config([
  '$routeProvider'
  '$locationProvider'

($routeProvider, $locationProvider, config) ->

  $routeProvider

    .when('/', {templateUrl: '/partials/devices.html'})
    .when('/devices/:deviceId', {templateUrl: '/partials/device-view.html'})

    # Catch all
    .otherwise({redirectTo: '/'})

  # Without server side support html5 must be disabled.
  $locationProvider.html5Mode(false)
])
