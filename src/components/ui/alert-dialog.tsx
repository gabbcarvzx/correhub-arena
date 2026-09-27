"use client";

import * as AlertDialogPrimitive from "@radix-ui/react-alert-dialog";
import type { ReactNode } from "react";

export function ConfirmAction({ trigger, title, description, confirmLabel, onConfirm, destructive = false }: {
  trigger: ReactNode; title: string; description: string; confirmLabel: string; onConfirm: () => void | Promise<void>; destructive?: boolean;
}) {
  return <AlertDialogPrimitive.Root>
    <AlertDialogPrimitive.Trigger asChild>{trigger}</AlertDialogPrimitive.Trigger>
    <AlertDialogPrimitive.Portal>
      <AlertDialogPrimitive.Overlay className="fixed inset-0 z-40 bg-foreground/45" />
      <AlertDialogPrimitive.Content className="fixed left-1/2 top-1/2 z-50 w-[min(30rem,calc(100vw-2rem))] -translate-x-1/2 -translate-y-1/2 border border-border bg-surface p-6 shadow-xl">
        <AlertDialogPrimitive.Title className="text-2xl font-black">{title}</AlertDialogPrimitive.Title>
        <AlertDialogPrimitive.Description className="mt-3 leading-7 text-muted">{description}</AlertDialogPrimitive.Description>
        <div className="mt-7 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <AlertDialogPrimitive.Cancel className="min-h-11 px-5 font-bold text-muted">Cancelar</AlertDialogPrimitive.Cancel>
          <AlertDialogPrimitive.Action className={`min-h-11 rounded-full px-5 font-black ${destructive ? "bg-destructive text-white" : "bg-primary text-on-primary hover:bg-primary-hover"}`} onClick={onConfirm}>{confirmLabel}</AlertDialogPrimitive.Action>
        </div>
      </AlertDialogPrimitive.Content>
    </AlertDialogPrimitive.Portal>
  </AlertDialogPrimitive.Root>;
}
