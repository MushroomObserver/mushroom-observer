
var form_Primary_List;
var form_Secondary_List;
var button_Submit_Choice;

//list that display the results
var ul_vernacular_terms;
var ul_species_terms;
var ul_selection_history;
var ul_all_feature_value_pairs; //all related feature value pairs

//Elements that are currently being visually displayed
var element_Primary_Feature; //Primary Feature being viewed
var element_Secondary_Feature; //Secondary Feature being viewed
var highlighted_element; //represents the elements you are scrolling over
/** 
Lists to be manipulated
**/
var list_Primary_List=new Array(); //List with primary elements String Elements
var list_Secondary_List=new Array(); //The subelements of the primary list String Elemenets
var list_Ignore_List=new Array(); // Associative array Items to be ignored on update of primary List - "Associative Array" so Ignore["Color"]="Color"
var list_Selected_Feature_Value_Pairs=new Array(); //keeps a list of selected values for a given feature - really a map
var list_Selected_Features=new Array(); //THe features you have selected
/**
Fake information to be added to List till we query an actual list
**/
/**
 list_Primary_List[1]="stipe flesh color";
 list_Primary_List[0]="hymonosphore shape";
 list_Primary_List[2]="habitat";
 list_Secondary_List[0]="orange";
 list_Secondary_List[1]="some white";
 list_Secondary_List[2]="brown";
 
 var fakeAlt=["pine","fir","woods"]; //Normally Secondary List would be updated through querying database
 var fakeAlt2=["some gilled", "spore mass"];
 var relateLists=new Array();
 relateLists[list_Primary_List[1]]=list_Secondary_List;
 relateLists[list_Primary_List[0]]=fakeAlt2;
 relateLists[list_Primary_List[2]]=fakeAlt;
 
 **/
 var vernacular_list=[];//new Array("Pine Spike","White Russula","Generic Truffle");
 var species_list=[];//new Array("Chroogomphus ochraceus","Russula brevipes","Russula cremoricolor","Elaphomyces muricatus");
 var map_lists=new Array();
 
 var iterate=0;
    map_lists[ vernacular_list[0]]="Chroogomphus ochraceus";
    map_lists[ vernacular_list[1]]="Russula brevipes";
    map_lists[ vernacular_list[1]+"1"]="Russula cremoricolor";
    map_lists[ vernacular_list[2]]="Elaphomyces muricatus";
//has hymonosphore shape some gilled
//has stipe flesh color some white
//has habitat some fir

//has habitat some pine 
//has hymonosphore shape some gilled
//stipe flesh color Ornage


//has hymonosphore shape spore mass
//has color na
 //habitat woods
/** End **/

/**Accessor and update functions **/
function getElement(string_name){
  return document.getElementById(string_name);
}

//Sets the form and button in onload
function setElements(){
  form_Primary_List= getElement("Primary");
  form_Primary_List.onchange=list_primary_on_change;
  form_Secondary_List= getElement("Secondary");
  form_Secondary_List.onchange=list_secondary_on_change;
  button_Submit_Choice= getElement("Main_Button");
  ul_vernacular_terms=getElement("Vernacular");
  ul_species_terms=getElement("Species");
  ul_selection_history=getElement("History");
  ul_all_feature_value_pairs=getElement("Related_features");
  
}

//updates what option values of the selectElements are currently being viewed
function setCurrentlyViewedOptions(){
  if(form_Primary_List.options.selectedIndex==-1){}
  else {  
   element_Primary_Feature=form_Primary_List[ form_Primary_List.options.selectedIndex];
   element_Secondary_Feature=form_Secondary_List[form_Secondary_List.options.selectedIndex];
   }
}

//Makes some query to the database, and updates the list - done on submit
function update_primary_list (){
   //do some query
    //set list_primary to query return
    //SHOULD NOT BE DONE HERE set_selection_options(form_Primary_List, list_Primary_List);

    input["features"]=[(element_Primary_Feature.text)];
    input["values"]=[element_Secondary_Feature.text];
    submitQuery(4); 
    var list_primary_on_change_doit=setInterval(inner,4);
    function inner(){
	if(save_queries[4]!=undefined) clearInterval( list_primary_on_change_doit)
	else return;
     //change primary list so already seen values do not exist
     //alert(save_queries[4]);
       
	var i=0;
	//for(i=0;i<save_queries.length;i++) list_Primary_List.push(save_queries[4][i]);
	list_Primary_List=append_to_ary(list_Primary_List,save_queries[4]);
	list_Primary_List = create_arry_ignoring_seen_before(list_Ignore_List,list_Primary_List);
	
 
     //update primary options
     set_selection_options(form_Primary_List,list_Primary_List);
     
     //update secondary options
     list_primary_on_change();
     clearStateInfo();
     save_queries[4]=undefined;
   }
   
    
 }
//updates secondary list based on checking what the primary item that is currently viewed - done list_primary_form.onchange or onsubmit
function update_secondary_list(){
     setCurrentlyViewedOptions();
     
     input["features"]=[(element_Primary_Feature.text)]; //set the array value for input["feature"]
     submitQuery(3);
 
     
 
    // list_Secondary_List=relateLists[element_Primary_Feature.text];
     
}
var boolean_first_iteration_species=true;
//UPDATE LISTS related to history and species and vernacular
function update_species_ul_list(){
  
    input["features"]=[(element_Primary_Feature.text)];
    input["values"]=[element_Secondary_Feature.text];
   
    submitQuery(6);
    var list_primary_on_change_doit=setInterval(inner,4);
    function inner(){
	if(save_queries[6]!=undefined) clearInterval( list_primary_on_change_doit)
	else return;
	
	//alert(species_list+" GAP"+save_queries[6]);
	if(boolean_first_iteration_species==true) species_list=save_queries[6];
	else {  
		//PLEASE NOTE temporary
		if(save_queries[6].length>0) species_list=intersect(species_list,save_queries[6]);
	}
	
	boolean_first_iteration_species=false;
	
	
	
	set_html_list_values(ul_species_terms,species_list);
	save_queries[6]=undefined;
	
	
       clearStateInfo();
    }
    
    //species_list.splice(0,1);

}
var boolean_first_iteration=true;
function update_vernacular_ul_list(){
    input["features"]=[(element_Primary_Feature.text)];
    input["values"]=[element_Secondary_Feature.text];
   
    submitQuery(5);
    var list_primary_on_change_doit=setInterval(inner,4);
    function inner(){
	if(save_queries[5]!=undefined) clearInterval( list_primary_on_change_doit)
	else return;
	
	
	
	if(boolean_first_iteration==true) vernacular_list=save_queries[5];
	else vernacular_list=intersect(vernacular_list,save_queries[5]);
	boolean_first_iteration=false;
	
	set_html_list_values(ul_vernacular_terms,vernacular_list);
	save_queries[5]=undefined;
	
	
       clearStateInfo();
    }
    
}

function update_history(){
     var new_history=new Array();
     var i=0;
    for(i in list_Selected_Feature_Value_Pairs){
       new_history[i]=i+" : "+list_Selected_Feature_Value_Pairs[i]+" - <b>Basis</b> : Nathan ";
    }
    set_html_list_values(ul_selection_history,new_history);
}

//END

//dynamically calls query every 40ms till it gets the appropriate data -Poor style :(
function list_primary_on_change(){
  var list_primary_on_change_doit=setInterval(inner,4);
   setCurrentlyViewedOptions();
 
   update_secondary_list();
 
  //embedded function
   function inner(){ 
  //if you succeed continue, else wait
	if(save_queries[3]!=undefined) clearInterval( list_primary_on_change_doit)
	else return;
	
  
	list_Secondary_List=query_labels;
        setCurrentlyViewedOptions();
	if(list_Primary_List.length==0) list_Secondary_List=new Array();
	set_selection_options(form_Secondary_List,list_Secondary_List);
	getElement("new-value").innerHTML="Enter Unseen Value for "+element_Primary_Feature.text;
	clearStateInfo();
	save_queries[3]=undefined;
	
  }
 
}

function list_secondary_on_change(){
    
}

function button_submit_choice_on_click(){
    if(species_list.length==1) list_Primary_List=new Array();
     
     setCurrentlyViewedOptions();
     /** Save Values **/
     //Feature to never be seen on list again
     list_Ignore_List[element_Primary_Feature.text]=element_Primary_Feature.text;
     //Feature and value to be saved
     if(element_Secondary_Feature!=undefined) list_Selected_Feature_Value_Pairs[element_Primary_Feature.text]=element_Secondary_Feature.text;
     else list_Selected_Feature_Value_Pairs[element_Primary_Feature.text]="No Term";
     list_Selected_Features[element_Primary_Feature.text]=element_Primary_Feature.text; // This is the same as Ignore_List, unless for some reason IgnoreList includes other stuff
     /** **/
     
 
     //New query list
    update_primary_list();
  
        
      // needs to be changed and updates history
       update_species_ul_list();
      update_vernacular_ul_list();
      update_history();
    
      
      //Update Vernaulcar and species  html_List   
   //  set_html_list_values(ul_vernacular_terms,vernacular_list);

     
     
     if(vernacular_list.length==1) list_Primary_List=new Array();

       list_primary_on_change();
       
}
/** End Of Accessor and Update Functions**/

/** Conversion to select element options from string values **/

/**Takes a string list and sets the values to those in the form field **/
function set_selection_options(form_value, list_string){
  var options=convert_strings_to_options(list_string);
   //delete all values past the current one
  while(form_value.options.length>list_string.length){
      form_value.remove(form_value.options[form_value.options.length-1]);
   }
  
  var i=0;
  
  for(i =0;i<list_string.length;i++){
     form_value.options[i]=options[i];
      }
 
}
/**Takes an array and converts it to an array of objects **/
function convert_strings_to_options(list_string){
    var i=0;
    option_array=new Array();
    for(i=0;i<list_string.length;i++){
      option_array[i]=convert_string_to_option_not_first(list_string[i]);
  
    }
    return option_array;
}
/**Takes String and returns an Option HTML object **/
function convert_string_to_option(String_V, shouldBeViewed){
  // alert(String_V);
  var converted=new Option(String_V, String_V, true, shouldBeViewed);
   return converted;
}
function convert_string_to_option_not_first(String_V){
   return convert_string_to_option(String_V, false);
}

//converts a string to an li element
function convert_string_to_li(String_V){
  var value=document.createElement("LI");
  value.innerHTML=String_V;
  return value;
}
 //JUST PLAYING AROUDN SEE set_html_list stuff
 var  li_feature_value_pair=[]; // atemporary list
 
 //NOT USED
 function get_source(){
     submitQuery(9);
       var nameOfParent=highlighted_element.parentNode.id;
       input[""+nameOfParent]=[""+highlighted_element.innerHTML];
    var list_primary_on_change_doit=setInterval(inner,4);
    function inner(){
	
	if(save_queries[9]!=undefined) clearInterval( list_primary_on_change_doit)
	else return;
	if(highlighted_element==undefined) {
		
		//return;
	}
	ul_all_feature_value_pairs.innerHTML="BASIS NATHAN\n"+ul_all_feature_value_pairs.innerHTML;
	save_queries[9]=undefined;
    }
 }
 function set_association(){
 //highlighted_element; //represents the elements you are scrolling over
    
    var whichQuery=8;
     
    if(highlighted_element.parentNode.id=="Vernacular") whichQuery=7;
  
  
    var nameOfParent=highlighted_element.parentNode.id;
    
    if(nameOfParent=="Vernacular") nameOfParent="vernaculars";
    else nameOfParent="species";
    input[""+nameOfParent]=[""+highlighted_element.innerHTML];
  
    submitQuery(whichQuery);
    
    var list_primary_on_change_doit=setInterval(inner,4);
    function inner(){
	if(save_queries[whichQuery]!=undefined&&query_urls.length>-1) clearInterval( list_primary_on_change_doit)
	else return;
	
	var iterate=0;
	
	for(iterate in query_features){
	  li_feature_value_pair.push(query_features[iterate]+" : "+query_values[iterate]);
	}
	set_html_list_values(ul_all_feature_value_pairs,li_feature_value_pair);
	
	
	save_queries[whichQuery]=undefined;
	
	makeRED(ul_selection_history,ul_all_feature_value_pairs);
       clearStateInfo();
    }
    
 }
 
 
 
 function makeRED(ul_list1,ul_list2){
	for(g in ul_list1.childNodes){
	   if(ul_list1.childNodes[g].style==undefined) continue;
	    var element_val=ul_list1.childNodes[g];
	
	    for(gg in ul_list2.childNodes){
	       if(ul_list2.childNodes[gg].style==undefined) continue;
	      var element_val2=ul_list1.childNodes[gg].innerHTML;
	     // alert(element_val2+" "+element_val+" "+element_val2==element_val);
	      if(element_val.innerHTML==element_val2){
		element_val.style.color="red";
	      }
	    }
	}
 }
 function unRED(ul_list1){
	for(g in ul_list1.childNodes){
	     if(ul_list1.childNodes[g].style!=undefined)
		ul_list1.childNodes[g].style.color="black";
	}
 }
 function enter (){
     li_feature_value_pair=[];
     var parentName=this.parentNode.id;
     if(!(parentName=="Vernacular"||parentName=="Species")) return;
     if(this.innerHTML==undefined) return;
     highlighted_element=this;
     set_association();
     //this.innerHTML="<b>"+  this.innerHTML+"</b>";
     
      this.style.color="red";
        for(g in ul_species_terms.childNodes){
   
     }
     
     }
   function leave(){
      li_feature_value_pair=[];
     
      if(this.innerHTML==undefined) return;
       this.style.color="black";
   
    
      highlighted_element=undefined;
        unRED(ul_selection_history);
	set_html_list_values(ul_all_feature_value_pairs,li_feature_value_pair);
     }
  
function set_html_list_values(html_list, list_string){
   html_list.innerHTML="";
   
   var i=0;
   for(i in list_string){
    
     var element_loc=convert_string_to_li(list_string[i]);
    
     html_list.appendChild(element_loc);
      
   }
   var l=0;
   //THIS IS JUST TESTING OUT COLOR MATCHING
   for(l in html_list.childNodes){
      temp=html_list.childNodes[l];
      html_list.childNodes[l].onmouseover=enter;
      html_list.childNodes[l].onmouseout=leave;
	   
   }
}

/**End of conversion to list structure**/

/**Removing and modifying arrays to relative to associative array - no duplicates, or values that are unwanted**/
/**create new array with values seen before removed**/
function create_arry_ignoring_seen_before(associative_arry,list_string){
    var new_list=new Array();
    for(val in list_string){
      var temp=list_string[val];
      
      if(associative_arry[temp]==temp){}
      else { 
        new_list.push(temp);
       
        }
  }
       return new_list;
}
//buggy?
function contains(ary_1,val){
 
  for(value in ary_1){
     if(ary_1[value]==val) return true;
  }
  
  return false;
}
//intersection of two arrays
function intersect(ary_1,ary_2){
  var new_ary=[];
  for(v in ary_1){
     var val=ary_1[v];
    for(v1 in ary_2){
      var val2=ary_2[v1];
      if(val==val2) {
        new_ary.push(val2);
	break;
      }
    }
  }
  return new_ary;
}

function append_to_ary(ary_1,ary_2){
     
   for(value in ary_2){
     
   
        ary_1.push(ary_2[value]);
	
   }
   return ary_1;
}
/** **/

window.onload=setStartPage;

var starting_page;
function setStartPage(){

   submitQuery(1);
   starting_page=setInterval(startPage,20);
}
function startPage (){
  
   //do start page when content has finally loaded
   if(boolean_query_ready==true) clearInterval(starting_page);
   else return;
   
  setElements();
  list_Primary_List=query_labels;
  
  
  set_selection_options(form_Primary_List,list_Primary_List);
   // set_selection_options(ul_vernacular_terms,list_Primary_List);
  setCurrentlyViewedOptions();
  list_primary_on_change();
  button_Submit_Choice.onclick=button_submit_choice_on_click;
 
     //set html lists related to species and vernacular terms
     set_html_list_values(ul_vernacular_terms,vernacular_list);
     set_html_list_values(ul_species_terms,species_list);
 
 clearStateInfo();
 
 
}


