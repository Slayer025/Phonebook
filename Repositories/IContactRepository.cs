using PhonebookApp.Models;

namespace PhonebookApp.Repositories
{
    public interface IContactRepository
    {
        PagedResult<Contact> GetContactsPaged(int pageNumber, int pageSize, string searchTerm);
        Contact GetContactById(int id);
        int InsertContact(Contact contact);
        bool UpdateContact(Contact contact);
        bool DeleteContact(int id);
    }
}
