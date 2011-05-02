filter = function(text) {
  if (text == "") {
    $('.filterable').show();
    $('.hide').show();
    $('#aggrlink').hide();
  } else {
    $(".filterable[id!='" + text + "']").hide();
    $(".filterable[id*='" + text + "']").show();
    $('.hide').hide();

    var aggrs = "";
    var aggrcount = 0;
    $(".filterable[id*='" + text + "'] img").each(function() {
        var id = this.getAttribute('data-plot-id')
        if (aggrs.length > 0 ) {
        aggrs += '+';
        }
        aggrs += id;
        aggrcount += 1;
        });

    if (aggrcount > 1) {
      $('#aggrlink a').attr('href', 'rtgplot.cgi?id=' + aggrs + '&secs=86400&title=Aggregate+graph+for+' + text);
      $('#aggrlink').show();
    } else {
      $('#aggrlink').hide();
    }
  }
}

$(document).ready(function() {
    if ($('.filterable').length > 0) {
    var sb = $('#search')
    sb.keyup(function() {
      filter(sb.val());
      });
    filter(sb.val());
    $('#searchbox').show();
    sb.focus();
    }

    // Find the div containing aggregate graphs
    graphs = $('#aggrGraphs');
    if (graphs.length > 0) {
      $('#aggrChecked')[0].checked = (getCookie('aggrChecked') == "true");
      if (!$('#aggrChecked')[0].checked) {
        // Prevent the images from loading
        graphs.find("img").each(removeImgSrc);
        // Hide the div
        graphs.hide();
      }
      // Wire up the checkbox to show them
      $('#aggrChecked').click(aggrCheckedClicked);
      // Show the checkbox
      $('#showAggr').show();
    }
});

function removeImgSrc() {
  img = $(this);
  src = img.attr('src');
  img.removeAttr('src');
  img.attr('data-src', src);
  img.loaded = false;
}

function aggrCheckedClicked() {
  if (this.checked) {
    graphs.show();
    graphs.find("img").each(function() {
        img = $(this);
        src = img.attr('data-src');
        img.attr('src', src);
        });
  } else {
    graphs.hide();
  }

  setCookie('aggrChecked', this.checked, 30);
}

function getCookie(name) {
  var cookieValue = null;
  if (document.cookie && document.cookie != '') {
    var cookies = document.cookie.split(';');
    for (var i = 0; i < cookies.length; i++) {
      var cookie = jQuery.trim(cookies[i]);
      if (cookie.substring(0, name.length + 1) == (name + '=')) {
        cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
        break;
      }
    }
  }
  return cookieValue;
}

function setCookie(name, value, expiresIn) {
  if (value === null) {
    value = '';
    expiresIn = -1;
  }
  var expires = '';
  if (expiresIn && (typeof expiresIn == 'number' || expiresIn.toUTCString)) {
    var date;
    if (typeof expiresIn == 'number') {
      date = new Date();
      date.setTime(date.getTime() + (expiresIn * 24 * 60 * 60 * 1000));
    } else {
      date = expiresIn;
    }
    expires = '; expires=' + date.toUTCString();
  }
  document.cookie = [name, '=', encodeURIComponent(value), expires].join('');
}

