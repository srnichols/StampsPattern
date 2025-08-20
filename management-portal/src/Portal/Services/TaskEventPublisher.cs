using HotChocolate;
using HotChocolate.Subscriptions;
using System.Threading.Tasks;
using Stamps.ManagementPortal.GraphQL;

namespace Stamps.ManagementPortal.Services
{
    public interface ITaskEventPublisher
    {
        Task PublishTaskEventAsync(TaskEvent taskEvent);
    }

    public class TaskEventPublisher : ITaskEventPublisher
    {
        private readonly ITopicEventSender _eventSender;
        public TaskEventPublisher(ITopicEventSender eventSender)
        {
            _eventSender = eventSender;
        }
        public async Task PublishTaskEventAsync(TaskEvent taskEvent)
        {
            await _eventSender.SendAsync("TASK_EVENTS", taskEvent);
        }
    }
}
