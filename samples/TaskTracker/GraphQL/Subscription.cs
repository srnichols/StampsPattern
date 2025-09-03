using HotChocolate;
using HotChocolate.Subscriptions;
using TaskTracker.Blazor.Models;

namespace TaskTracker.Blazor.GraphQL;

public class Subscription
{
    [Subscribe]
    [Topic]
    public TaskItem OnTaskCreated([EventMessage] TaskItem task) => task;

    [Subscribe]
    [Topic]
    public TaskItem OnTaskUpdated([EventMessage] TaskItem task) => task;

    [Subscribe]
    [Topic]
    public Guid OnTaskDeleted([EventMessage] Guid taskId) => taskId;
}
