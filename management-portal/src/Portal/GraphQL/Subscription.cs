using HotChocolate;
using HotChocolate.Subscriptions;
using System.Threading;
using System.Threading.Tasks;

namespace Stamps.ManagementPortal.GraphQL
{
    public class TaskEvent
    {
        public string Id { get; set; }
        public string Status { get; set; }
        public string Message { get; set; }
        public DateTime Timestamp { get; set; }
    }

    public class Subscription
    {
        [Subscribe]
        [Topic("TASK_EVENTS")]
        public TaskEvent OnTaskEvent([EventMessage] TaskEvent taskEvent) => taskEvent;
    }
}
