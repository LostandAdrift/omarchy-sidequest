.pragma library

var ink = "#10131d";
var panel = "#191d2b";
var line = "#34394d";
var text = "#f0eee8";
var muted = "#a3a7bd";
var accent = "#c4b2ff";
var mint = "#b6edbc";
var gold = "#f2cd8a";

function emptyLibrary() {
    return {games:[], libraries:0, toolsHidden:0, notReady:0, warnings:[], scanMs:0};
}
function limitText(value, limit) {
    var text=String(value || ""), count=0, end=0;
    while(end<text.length && count<limit){
        var first=text.charCodeAt(end++);
        if(first>=0xd800 && first<=0xdbff && end<text.length){
            var next=text.charCodeAt(end);
            if(next>=0xdc00 && next<=0xdfff)end++;
        }
        count++;
    }
    return text.slice(0,end);
}
function characterCount(value) {
    var text=String(value || ""),count=0;
    for(var i=0;i<text.length;i++){
        var first=text.charCodeAt(i),next=text.charCodeAt(i+1);
        if(first>=0xd800 && first<=0xdbff && next>=0xdc00 && next<=0xdfff)i++;
        count++;
    }
    return count;
}
function normalize(value) {
    return String(value || "").toLowerCase().replace(/[^a-z0-9\u0080-\uffff]+/g, " ").trim();
}
function score(name, query) {
    var n=normalize(name), words=normalize(query).split(/\s+/), total=0;
    if(!normalize(query))return 1;
    for(var i=0;i<words.length;i++){
        var word=words[i], at=n.indexOf(word);
        if(at>=0){total+=at===0?100:60;continue;}
        var pos=0;
        for(var j=0;j<n.length && pos<word.length;j++)if(n[j]===word[pos])pos++;
        if(pos!==word.length)return 0;
        total+=10;
    }
    return total;
}
function filter(games, query, mode) {
    var matches=[];
    games.forEach(function(g){
        if(mode==="hidden" ? !g.hidden : g.hidden)return;
        if(mode==="favorites" && !g.favorite)return;
        if(mode==="notes" && !g.note)return;
        if(["quick","deep","party"].indexOf(mode)>=0 && g.mood!==mode)return;
        var rank=score(g.name,query);
        if(rank>0)matches.push({game:g,rank:rank});
    });
    // Score once per game, rather than repeatedly during sort comparisons.
    return matches.sort(function(left,right){
        var a=left.game,b=right.game,delta=right.rank-left.rank;
        if(delta)return delta;
        if(a.favorite!==b.favorite)return a.favorite?-1:1;
        return a.name.localeCompare(b.name);
    }).map(function(entry){return entry.game;});
}
function byId(games,id) {for(var i=0;i<games.length;i++)if(games[i].id===id)return games[i];return null;}
function sizeLabel(bytes) {
    if(!bytes)return "Size unknown";
    return bytes>=1073741824?(bytes/1073741824).toFixed(1)+" GB":Math.ceil(bytes/1048576)+" MB";
}
function lastPlayed(timestamp,now) {
    if(!timestamp)return "No play recorded by Steam";
    var days=Math.floor(Math.max(0,now/1000-timestamp)/86400);
    return days===0?"Played today":days===1?"Played yesterday":"Played "+days+" days ago";
}
function initials(name) {
    return String(name || "?").trim().split(/\s+/).slice(0,2).map(function(w){return w.charAt(0).toUpperCase();}).join("");
}
function hash(value) {
    var h=0;for(var i=0;i<String(value).length;i++)h=(h*31+String(value).charCodeAt(i))>>>0;return h;
}
function colors(id) {
    var sets=[['#192845','#526ba5','#aecff2'],['#29203d','#755997','#dbc0fc'],['#173333','#487e70','#c1e4b2'],['#382731','#9b606d','#f0bea4'],['#302f26','#8c8256','#f0dc9b']];
    return sets[hash(id)%sets.length];
}
function demoLibrary() {
    var names=["Starfall: Afterlight", "Neon Ronin", "Moss & Ember", "Orbit Breakers", "The Last Teahouse", "Moon Circuit", "Dungeon Delivery", "Pixel Pilgrims"];
    var notes=["The observatory door opens at dusk. Bring the prism from the old lighthouse.\n\nNext: find the cartographer on the floating island.","Practice the parry timing before the rooftop duel.","Find two more ember seeds for the winter garden.","", "The fox spirit asked for roasted barley tea.", "", "Deliver the suspiciously warm package.", ""];
    var games=[];
    for(var i=0;i<names.length;i++)games.push({id:String(700001+i),name:names[i],bytes:(3+i*4.5)*1073741824,lastPlayed:1788739200-i*86400,cover:"",note:notes[i],favorite:i===0 || i===2,mood:["deep","quick","quick","party","deep","quick","party","any"][i],hidden:false,updated:0,launched:0});
    return {games:games,libraries:2,toolsHidden:5,notReady:0,warnings:[],scanMs:7.4};
}
