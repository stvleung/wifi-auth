var AutoLogout = function() {
    return {
        REGULAR_CHECK_SESSION_EXPIRY_INTERVAL: 30 * 1000, // every 30 seconds
        FAST_CHECK_SESSION_EXPIRY_INTERVAL:    10 * 1000,    // every 10 seconds

        COUNT_DOWN_DURATION: 60 * 1000, // 60 seconds
        
        checkSessionExpiryTimer: null,
        updateCountDownTimer: null,

        start: function() {
            AutoLogout.setCheckSessionExpirySpeed(false);
        },

        setCheckSessionExpirySpeed: function(fast) {
            // clear any existing timer
            if (AutoLogout.checkSessionExpiryTimer) {
                clearInterval(AutoLogout.checkSessionExpiryTimer);
            }

            // set the interval based on speed
            var interval;

            if (fast) {
                interval = AutoLogout.FAST_CHECK_SESSION_EXPIRY_INTERVAL;
            }
            else {
                interval = AutoLogout.REGULAR_CHECK_SESSION_EXPIRY_INTERVAL;
            }

            // set the timer
            AutoLogout.checkSessionExpiryTimer = setInterval(AutoLogout.checkSessionExpiry, interval);
        },

        checkSessionExpiry: function(callback) {
            $.get('/account/check_session_expiry', function(durationSecs) {
                var durationMilliSecs = durationSecs * 1000;

                var oneMinute = 60 * 1000;

                // if we're within one minute of being logged, show the logout modal
                if ( durationMilliSecs <= ( AutoLogout.COUNT_DOWN_DURATION + oneMinute ) ) {
                    AutoLogout.showConfirmModal(durationMilliSecs);
                }
                // otherwise, hide it (since the session might've been extended in other windows)
                else {
                    AutoLogout.hideConfirmModal();
                }

                // if there is a callback, call it
                if ( callback ) {
                    callback(durationSecs);
                }
            });
        },
        
        showConfirmModal: function(durationMilliSecs) {
            if ($( "#auto-logout-confirmation" ).is(':visible')) {
                return;
            }
            
            // set the check expiry speed to fast
            AutoLogout.setCheckSessionExpirySpeed(true);

            if (durationMilliSecs > AutoLogout.COUNT_DOWN_DURATION) {
                durationMilliSecs = AutoLogout.COUNT_DOWN_DURATION;
            }

            AutoLogout.logoutTime = new Date().getTime() + durationMilliSecs;
            AutoLogout.updateCountDown();
			
			$('#auto-logout-confirmation').modal('show');
			
			$('#extend-session').click(function() {
				AutoLogout.hideConfirmModal();
                $.get('/account/extend_session');
			});
        },
        
        hideConfirmModal: function() {
            $('#auto-logout-confirmation').modal('hide');
            clearTimeout(AutoLogout.updateCountDownTimer);

            // set the check expiry speed to regular
            AutoLogout.setCheckSessionExpirySpeed(false);
        },

        updateCountDown: function() {
            var nowTime = new Date().getTime();
            
            var secondsLeft = Math.round((AutoLogout.logoutTime - nowTime) / 1000);
            
            if (secondsLeft >= 0) {
                $('#auto-logout-confirmation-seconds')[0].innerHTML = secondsLeft;
                AutoLogout.updateCountDownTimer = setTimeout(AutoLogout.updateCountDown, 0.25);
            }
            else {
                window.location.href = '/account/logout';
            }
        }
    };
}();

$(document).ready(function() {
    AutoLogout.start();
});
