using System;
using System.Web.Mvc;
using PhonebookApp.Models;
using PhonebookApp.Repositories;

namespace PhonebookApp.Controllers
{
    public class HomeController : Controller
    {
        private readonly IContactRepository _repo = new ContactRepository();

        private const int PageSize = 10;

        // GET: Home/Index
        public ActionResult Index(int? page, string searchTerm)
        {
            int pageNumber = page.HasValue && page.Value > 0 ? page.Value : 1;

            var result = _repo.GetContactsPaged(pageNumber, PageSize, searchTerm);

            ViewBag.SearchTerm = searchTerm;

            return View(result);
        }

        // GET: Home/Create
        public ActionResult Create()
        {
            return View();
        }

        // POST: Home/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Create(Contact contact)
        {
            if (ModelState.IsValid)
            {
                _repo.InsertContact(contact);
                return RedirectToAction("Index");
            }

            return View(contact);
        }

        // GET: Home/Edit/5
        public ActionResult Edit(int? id)
        {
            if (!id.HasValue)
            {
                return HttpNotFound();
            }

            var contact = _repo.GetContactById(id.Value);

            if (contact == null)
            {
                return HttpNotFound();
            }

            return View(contact);
        }

        // POST: Home/Edit
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Edit(Contact contact)
        {
            if (ModelState.IsValid)
            {
                _repo.UpdateContact(contact);
                return RedirectToAction("Index");
            }

            return View(contact);
        }

        // POST: Home/Delete/5
        [HttpPost]
        public JsonResult Delete(int? id)
        {
            if (!id.HasValue)
            {
                return Json(new { success = false, message = "Invalid contact id." });
            }

            try
            {
                bool success = _repo.DeleteContact(id.Value);

                if (success)
                {
                    return Json(new { success = true });
                }

                return Json(new { success = false, message = "Contact not found or could not be deleted." });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }
    }
}
