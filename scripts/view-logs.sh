#!/bin/bash

echo "📊 GitHub Runner Logs Viewer"
echo "============================"
echo ""
echo "Select which logs to view:"
echo "1) Webhook Lambda logs"
echo "2) Runner Lambda logs"
echo "3) Both (split terminal)"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        echo "📡 Viewing webhook logs (Ctrl+C to exit)..."
        aws logs tail /aws/lambda/github-runner-webhook --follow
        ;;
    2)
        echo "🏃 Viewing runner logs (Ctrl+C to exit)..."
        aws logs tail /aws/lambda/github-runner-executor --follow
        ;;
    3)
        echo "👀 Opening both logs..."
        echo "Press Ctrl+C to exit"
        echo ""
        # Try to use split terminal if available
        if command -v tmux &> /dev/null; then
            tmux new-session -d -s runner-logs
            tmux split-window -h
            tmux select-pane -t 0
            tmux send-keys "aws logs tail /aws/lambda/github-runner-webhook --follow" C-m
            tmux select-pane -t 1
            tmux send-keys "aws logs tail /aws/lambda/github-runner-executor --follow" C-m
            tmux attach-session -t runner-logs
        else
            echo "⚠️  tmux not installed. Showing webhook logs only."
            echo "Install tmux for split view or run in separate terminals"
            aws logs tail /aws/lambda/github-runner-webhook --follow
        fi
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

