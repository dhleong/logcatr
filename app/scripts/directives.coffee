'use strict'

### Directives ###

# register the module with Angular
angular.module('app.directives', [
  # require the 'app.service' module
  'app.services'
])

.directive('appVersion', [
  'version'

(version) ->

    (scope, elm, attrs) ->
        elm.text(version)
])

.directive('serverAddr', [
  'readableStatus'

(readableStatus) ->

    (scope, elm, attrs) ->
        elm.html readableStatus
])

.directive('device', [
    'imageFetcher'
(imageFetcher) ->
    restrict: 'E'
    templateUrl: '/partials/device-element.html'
    scope:
        info: '='
    
    link: ($scope, $el, $attr) ->

        imageFetcher.fetch($scope.info)
        .then (deviceImage) ->
            console.log 'fetched!', deviceImage
            $scope.deviceImage = deviceImage
            $scope.$apply()
])
        

.directive 'logcatEntry', ->
    restrict: 'E'
    templateUrl: '/partials/logcat-entry.html'
    scope:
        entry: '='

    link: ($scope, $el, $attr) ->
        entry = $scope.entry
        
        $scope.date = entry.date
        $scope.tag = entry.tag
        # $scope.message = entry.message
        $scope.message = entry.tag

        # TODO detect json in the message
        $scope.json = JSON.stringify(entry, undefined, 2)
