// If we get a success, replace the naming form
// TODO: Bind autocomplete to the form input
// TODO: maybe redo the title? Namings can change the obs title.

// window.addEventListener("load", () => {
//   const namingForm = document.querySelector("#naming_form");
//   const namingTable = document.querySelector("#naming_table");
//   const obsNamings = document.querySelector("#observation_namings");
//   const namingModal = document.querySelector("#modal_propose_naming");

//   namingForm.addEventListener("ajax:success", (event) => {
//     const [_data, _status, xhr] = event.detail;
//     document.body.removeChild(namingModal);
//     namingTable.parentNode.removeChild(namingTable);
//     obsNamings.insertAdjacentHTML("afterbegin", xhr.responseText);
//   });

//   namingForm.addEventListener("ajax:error", () => {
//     namingForm.insertAdjacentHTML("beforeend", "<p>ERROR</p>");
//   });
// });
