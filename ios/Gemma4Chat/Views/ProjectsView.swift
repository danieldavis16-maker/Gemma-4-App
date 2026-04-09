import SwiftUI

struct ProjectsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var showNewProject = false
    @State private var newProjectName = ""

    var body: some View {
        NavigationStack {
            List {
                // Default (no project) section
                Button {
                    viewModel.currentProject = nil
                    viewModel.showProjectsSheet = false
                } label: {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("General Chat")
                                .font(.body)
                                .foregroundColor(.primary)
                            Text("No project context")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if viewModel.currentProject == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }

                // Projects
                Section("Projects") {
                    ForEach(viewModel.projects) { project in
                        Button {
                            viewModel.switchToProject(project)
                            viewModel.showProjectsSheet = false
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    HStack(spacing: 8) {
                                        Text("\(project.conversationIds.count) chats")
                                        if !project.systemPrompt.isEmpty {
                                            Text("· Custom prompt")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                Spacer()
                                if viewModel.currentProject?.id == project.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteProject(viewModel.projects[index])
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.showProjectsSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Project", isPresented: $showNewProject) {
                TextField("Project name", text: $newProjectName)
                Button("Create") {
                    if !newProjectName.isEmpty {
                        viewModel.createProject(name: newProjectName)
                        newProjectName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newProjectName = ""
                }
            }
        }
    }
}
