(function(){
  $LAB
  .script("/jellyfish-serv/js/jquery-1.4.2.js").wait(function(){
    var $jellyQ = jQuery.noConflict();
    $jellyQ.post("/jellyfish-rpc", { method: "register", title: window.document.title, location: window.location.href } );
  });
})();
